import Foundation
import os
import SwiftUI


@MainActor
@Observable
final class SyncEngine {
    private enum Constants {
        static let defaultSyncIntervalMinutes: Double = 5
        static let pushDebounceNanoseconds: UInt64 = 2_000_000_000
        static let calendarPullDaysBack = -30
        static let calendarPullDaysForward = 60
    }

    static let shared = SyncEngine()

    private(set) var status: SyncStatus = .idle
    private(set) var lastFullSync: Date?
    private let tasksService = GoogleTasksService()
    private let calendarService = GoogleCalendarService()
    private let gmailService = GoogleGmailService()
    private let data = DataController.shared
    private let firestoreSync = FirestoreSyncService.shared
    private var syncTimer: Timer?
    private var lastTaskSync: Date?
    private var lastCalendarSync: Date?
    private var pushDebounceTask: Task<Void, Never>?

    var onSyncCompleted: (() -> Void)?


    /// Per-event sendUpdates preference (consumed on push, then cleared)
    var sendUpdatesOverrides: [String: String] = [:]
    var pendingListMoves: [String: String] = [:]
    private init() {}

    // MARK: - Periodic Sync

    func startPeriodicSync(intervalMinutes: Double = Constants.defaultSyncIntervalMinutes) {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: intervalMinutes * 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.syncAll()
            }
        }
    }

    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - Full Sync

    func syncAll() async {
        guard !status.isSyncing else { return }
        status = .syncing
        do {
            try await ensureCalendarsExist()
            try await pullTasks()
            try await pushTasks()
            try await pullCalendarEvents()
            try await pushCalendarEvents()
            if AppSettings.shared.gmailSyncEnabled {
                try await pullGmailStarred()
                try await pushGmailStars()
            }
            // Firestore cross-device sync (labels, task metadata, notes, settings)
            await firestoreSync.syncAll()
            lastFullSync = Date()
            status = .success(Date())
            // Update widget data after sync
            #if os(iOS)
            WidgetDataWriter.shared.writeWidgetData()
            #endif
            onSyncCompleted?()
        } catch {
            status = .error(error.localizedDescription)
            MadoLogger.sync.error("syncAll failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Quick Push (debounced, for local changes)

    func schedulePush() {
        pushDebounceTask?.cancel()
        pushDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Constants.pushDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            await pushLocalChanges()
        }
    }

    func pushLocalChanges() async {
        guard !status.isSyncing else {
            // Sync in progress — reschedule so pending changes aren't lost
            schedulePush()
            return
        }
        let previousStatus = status
        status = .syncing
        do {
            try await pushTasks()
            try await pushCalendarEvents()
            if AppSettings.shared.gmailSyncEnabled {
                try await pushGmailStars()
            }
            // Firestore cross-device push
            await firestoreSync.pushAll()
            status = previousStatus.isSyncing ? .success(Date()) : previousStatus
            if case .idle = status {
                status = .success(Date())
            }
            onSyncCompleted?()
        } catch {
            status = .error(error.localizedDescription)
            MadoLogger.sync.error("pushLocalChanges failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Primary Calendar ID

    func primaryCalendarId() -> String {
        if let calendars = try? data.fetchCalendars() {
            if let primary = calendars.first(where: { $0.isPrimary }) {
                return primary.googleCalendarId
            }
            if let selected = calendars.first(where: { $0.isSelected }) {
                return selected.googleCalendarId
            }
        }
        return "primary"
    }

    // MARK: - Calendar Bootstrap

    private func ensureCalendarsExist() async throws {
        let existing = try data.fetchCalendars()
        let accounts = AuthenticationManager.shared.accounts

        if existing.isEmpty {
            for account in accounts {
                do {
                    let response = try await calendarService.listCalendars(accountEmail: account.email)
                    guard let items = response.items else { continue }

                    for remote in items {
                        let isPrimary = remote.primary ?? false
                        let role = remote.accessRole ?? "reader"
                        let isOwned = role == "owner" || role == "writer"
                        let cal = UserCalendar(
                            googleCalendarId: remote.id,
                            name: remote.summary ?? "Untitled",
                            colorHex: remote.backgroundColor?.replacingOccurrences(of: "#", with: "") ?? "4A90D9",
                            isSelected: remote.selected ?? isPrimary,
                            isPrimary: isPrimary,
                            accessRole: role,
                            accountEmail: account.email,
                            notificationsEnabled: isPrimary && account.isPrimary,
                            showInMenuBar: isOwned
                        )
                        data.mainContext.insert(cal)
                    }
                } catch {
                    MadoLogger.sync.error("ensureCalendarsExist failed for \(account.email, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            data.save()
        } else {
            for cal in existing {
                if cal.isPrimary && !cal.notificationsEnabled {
                    cal.notificationsEnabled = true
                }
                let isOwned = cal.accessRole == "owner" || cal.accessRole == "writer"
                if !isOwned && cal.showInMenuBar {
                    cal.showInMenuBar = false
                }
            }
            let existingByGoogleId = Dictionary(existing.map { ($0.googleCalendarId, $0) }, uniquingKeysWith: { first, _ in first })
            for account in accounts {
                do {
                    let response = try await calendarService.listCalendars(accountEmail: account.email)
                    guard let items = response.items else { continue }

                    for remote in items {
                        if existingByGoogleId[remote.id] != nil {
                            continue
                        } else {
                            let role = remote.accessRole ?? "reader"
                            let isOwned = role == "owner" || role == "writer"
                            let cal = UserCalendar(
                                googleCalendarId: remote.id,
                                name: remote.summary ?? "Untitled",
                                colorHex: remote.backgroundColor?.replacingOccurrences(of: "#", with: "") ?? "4A90D9",
                                isSelected: remote.selected ?? false,
                                isPrimary: remote.primary ?? false,
                                accessRole: role,
                                accountEmail: account.email,
                                showInMenuBar: isOwned
                            )
                            data.mainContext.insert(cal)
                        }
                    }
                } catch {
                    MadoLogger.sync.error("ensureCalendarsExist failed for \(account.email, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            data.save()
        }
    }

    // MARK: - Pull Tasks

    private func pullTasks() async throws {
        let taskLists = try await tasksService.listTaskLists()
        guard let lists = taskLists.items else { return }
        for list in lists {
            let project = try upsertProject(for: list)
            let remoteTasks = try await tasksService.listAllTasks(
                listId: list.id,
                updatedMin: lastTaskSync
            )
            for remoteTask in remoteTasks {
                guard let remoteId = remoteTask.id else { continue }
                if let localTask = try data.findTask(byGoogleId: remoteId) {
                    if localTask.needsSync || pendingListMoves[localTask.id] != nil {
                        continue
                    }
                    if remoteTask.deleted == true {
                        localTask.isDeleted = true
                        localTask.needsSync = false
                        continue
                    }
                    let remoteUpdated = remoteTask.updated ?? Date.distantPast
                    if remoteUpdated > localTask.localUpdatedAt {
                        localTask.title = remoteTask.title ?? localTask.title
                        localTask.notes = remoteTask.notes
                        // Don't let a stale remote status un-complete a task the user
                        // already marked done locally (push may not have propagated yet).
                        let localCompletedAfterRemote = localTask.completedAt.map { $0 > remoteUpdated } ?? false
                        if !localCompletedAfterRemote {
                            localTask.isCompleted = remoteTask.isDone
                        }
                        localTask.googleUpdatedAt = remoteTask.updated
                        localTask.localUpdatedAt = Date()
                        localTask.needsSync = false
                        localTask.projectId = project.id
                    }
                } else if remoteTask.deleted != true && !remoteTask.isDone {
                    let title = remoteTask.title ?? "Untitled"

                    if let existing = try? data.findExistingTask(title: title, projectId: project.id) {
                        existing.googleTaskId = remoteId
                        existing.googleTaskListId = list.id
                        existing.googleUpdatedAt = remoteTask.updated
                        existing.needsSync = false
                        continue
                    }

                    let newTask = MadoTask(
                        title: title,
                        notes: remoteTask.notes,
                        isCompleted: false,
                        googleTaskId: remoteId,
                        googleTaskListId: list.id,
                        projectId: project.id
                    )
                    newTask.googleUpdatedAt = remoteTask.updated
                    newTask.needsSync = false
                    data.createTask(newTask)
                }
            }
        }
        lastTaskSync = Date()
        data.save()
    }
    private func upsertProject(for list: GoogleTaskListDTO) throws -> Project {
        if let existing = try data.findProject(byGoogleTaskListId: list.id) {
            if let title = list.title, existing.name != title {
                existing.name = title
            }
            return existing
        }
        let projects = (try? data.fetchProjects()) ?? []
        let project = Project(
            name: list.title ?? "Untitled",
            position: projects.count,
            googleTaskListId: list.id
        )
        data.createProject(project)
        return project
    }

    // MARK: - Push Tasks

    private func pushTasks() async throws {
        let pending = try data.fetchTasksNeedingSync()

        for task in pending {
            do {
                let listId = task.googleTaskListId ?? "@default"
                let dto = GoogleTaskDTO.from(task: task)

                if let googleId = task.googleTaskId,
                   let oldListId = pendingListMoves.removeValue(forKey: task.id) {
                    try? await tasksService.deleteTask(listId: oldListId, taskId: googleId)
                    var createDto = dto
                    createDto.id = nil
                    let created = try await tasksService.createTask(listId: listId, task: createDto)
                    task.googleTaskId = created.id
                    task.googleTaskListId = listId
                    task.googleUpdatedAt = created.updated
                } else if let googleId = task.googleTaskId {
                    if task.isDeleted {
                        try await tasksService.deleteTask(listId: listId, taskId: googleId)
                    } else {
                        let updated = try await tasksService.updateTask(listId: listId, taskId: googleId, task: dto)
                        task.googleUpdatedAt = updated.updated
                    }
                } else if !task.isDeleted {
                    let created = try await tasksService.createTask(listId: listId, task: dto)
                    task.googleTaskId = created.id
                    task.googleTaskListId = listId
                    task.googleUpdatedAt = created.updated
                }
                task.needsSync = false
            } catch let error as APIError where error == .notFound || error == .gone {
                task.needsSync = false
                task.isDeleted = true
            } catch {
                MadoLogger.sync.error("pushTask failed for '\(task.title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            }
        }
        data.save()
    }

    // MARK: - Pull Calendar Events

    private func pullCalendarEvents() async throws {
        let allCals = try data.fetchCalendars()
        let allCalendars = allCals.filter(\.isSelected)
        MadoLogger.sync.info("pullCalendarEvents: \(allCalendars.count)/\(allCals.count) selected calendars")
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: Constants.calendarPullDaysBack, to: now)!
        let sixtyDaysAhead = Calendar.current.date(byAdding: .day, value: Constants.calendarPullDaysForward, to: now)!
        let deletedSeriesIds = (try? data.findDeletedRecurringEventSeriesIds()) ?? []

        for calendar in allCalendars {
            let calendarId = calendar.googleCalendarId
            let calAccountEmail = calendar.accountEmail.isEmpty ? nil : calendar.accountEmail
            do {
                let remoteEvents = try await calendarService.listAllEvents(
                    calendarId: calendarId,
                    timeMin: thirtyDaysAgo,
                    timeMax: sixtyDaysAhead,
                    accountEmail: calAccountEmail
                )
                var newCount = 0
                var updatedCount = 0
                var cancelledCount = 0

                for remoteEvent in remoteEvents {
                    guard let remoteId = remoteEvent.id else { continue }
                    guard remoteEvent.status != "cancelled" else {
                        cancelledCount += 1
                        if let local = try data.findEvent(byGoogleId: remoteId) {
                            local.isDeleted = true
                            local.needsSync = false
                        }
                        continue
                    }

                    let startDate = remoteEvent.start?.asDate ?? now
                    let endDate = remoteEvent.end?.asDate ?? startDate
                    let isAllDay = remoteEvent.start?.isAllDay ?? false

                    if let local = try data.findEvent(byGoogleId: remoteId) {
                        if local.isDeleted {
                            if local.needsSync {
                                MadoLogger.sync.debug("pull: skipping '\(local.title, privacy: .public)' — pending local delete")
                                continue
                            }
                            local.isDeleted = false
                            MadoLogger.sync.info("pull: restored '\(remoteEvent.summary ?? "?", privacy: .public)' — exists on Google but was locally deleted")
                        }
                        
                        if local.calendarId != calendarId {
                            local.calendarId = calendarId
                        }
                        
                        if local.needsSync {
                            continue
                        }
                        let remoteUpdated = remoteEvent.updated ?? Date.distantPast
                        if remoteUpdated > local.localUpdatedAt {
                            local.title = remoteEvent.summary ?? local.title
                            local.notes = remoteEvent.description
                            local.location = remoteEvent.location
                            local.startDate = startDate
                            local.endDate = endDate
                            local.isAllDay = isAllDay
                            local.etag = remoteEvent.etag
                            local.colorId = remoteEvent.colorId
                            local.googleUpdatedAt = remoteEvent.updated
                            local.localUpdatedAt = Date()
                            local.needsSync = false
                            local.accountEmail = calendar.accountEmail
                            local.attendeesJSON = Self.encodeAttendees(remoteEvent.attendees)
                            local.organizerEmail = remoteEvent.organizer?.email
                            local.organizerName = remoteEvent.organizer?.displayName
                            local.conferenceURL = remoteEvent.hangoutLink ?? remoteEvent.conferenceData?.entryPoints?.first(where: { $0.entryPointType == "video" })?.uri
                            local.conferenceName = remoteEvent.conferenceData?.conferenceSolution?.name
                            local.htmlLink = remoteEvent.htmlLink
                        }

                        if local.attendeesJSON == nil, let remoteAttendees = remoteEvent.attendees, !remoteAttendees.isEmpty {
                            local.attendeesJSON = Self.encodeAttendees(remoteEvent.attendees)
                        }
                        if local.organizerEmail == nil {
                            local.organizerEmail = remoteEvent.organizer?.email
                            local.organizerName = remoteEvent.organizer?.displayName
                        }
                    } else {
                        if let recurringId = remoteEvent.recurringEventId,
                           deletedSeriesIds.contains(recurringId) {
                            try? await calendarService.deleteEvent(
                                calendarId: calendarId,
                                eventId: remoteId,
                                accountEmail: calAccountEmail
                            )
                            continue
                        }

                        let newEvent = CalendarEvent(
                            googleEventId: remoteId,
                            calendarId: calendarId,
                            title: remoteEvent.summary ?? "Untitled",
                            notes: remoteEvent.description,
                            location: remoteEvent.location,
                            startDate: startDate,
                            endDate: endDate,
                            isAllDay: isAllDay,
                            recurrenceRules: remoteEvent.recurrence,
                            recurringEventId: remoteEvent.recurringEventId,
                            etag: remoteEvent.etag,
                            colorId: remoteEvent.colorId,
                            accountEmail: calendar.accountEmail
                        )
                        newEvent.googleUpdatedAt = remoteEvent.updated
                        newEvent.attendeesJSON = Self.encodeAttendees(remoteEvent.attendees)
                        newEvent.organizerEmail = remoteEvent.organizer?.email
                        newEvent.organizerName = remoteEvent.organizer?.displayName
                        newEvent.conferenceURL = remoteEvent.hangoutLink ?? remoteEvent.conferenceData?.entryPoints?.first(where: { $0.entryPointType == "video" })?.uri
                        newEvent.conferenceName = remoteEvent.conferenceData?.conferenceSolution?.name
                        newEvent.htmlLink = remoteEvent.htmlLink
                        data.createEvent(newEvent)
                        newCount += 1
                    }
                }
                if remoteEvents.count > 0 || newCount > 0 {
                    MadoLogger.sync.info("pull '\(calendar.name, privacy: .public)': \(remoteEvents.count) remote, \(newCount) new, \(cancelledCount) cancelled")
                }

                // Reconciliation: soft-delete local events that no longer exist in Google
                let remoteIds = Set(remoteEvents.compactMap(\.id))
                let localEvents = try data.fetchEvents(
                    from: thirtyDaysAgo,
                    to: sixtyDaysAhead,
                    calendarIds: [calendarId]
                )
                for local in localEvents {
                    guard !local.isDeleted,
                          !local.needsSync,
                          !local.googleEventId.isEmpty,
                          !remoteIds.contains(local.googleEventId) else { continue }
                    local.isDeleted = true
                    local.needsSync = false
                    MadoLogger.sync.info("reconcile: removed stale event '\(local.title, privacy: .public)' (googleId: \(local.googleEventId, privacy: .public))")
                }
            } catch {
                MadoLogger.sync.error("pullCalendarEvents failed for '\(calendarId, privacy: .public)' (\(calendar.accountEmail, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            }
        }
        lastCalendarSync = Date()
        data.save()
    }

    // MARK: - Push Calendar Events

    private func pushCalendarEvents() async throws {
        let pending = try data.fetchEventsNeedingSync()
        MadoLogger.sync.info("pushCalendarEvents: \(pending.count) pending, deleted: \(pending.filter(\.isDeleted).count)")

        for event in pending {
            do {
                let calId = event.calendarId.isEmpty ? primaryCalendarId() : event.calendarId
                let eventAccountEmail = event.accountEmail.isEmpty ? nil : event.accountEmail
                let dto = GoogleEventDTO.from(event: event)

                if event.isDeleted {
                    guard !event.googleEventId.isEmpty else {
                        MadoLogger.sync.debug("skip delete for local-only event '\(event.title, privacy: .public)'")
                        event.needsSync = false
                        continue
                    }
                    MadoLogger.sync.info("DELETE event '\(event.title, privacy: .public)' (\(event.googleEventId, privacy: .public)) from calendar \(calId, privacy: .public)")
                    try await calendarService.deleteEvent(calendarId: calId, eventId: event.googleEventId, accountEmail: eventAccountEmail)
                    MadoLogger.sync.info("DELETE succeeded for '\(event.title, privacy: .public)'")
                } else if event.googleEventId.isEmpty {
                    let created = try await calendarService.createEvent(calendarId: calId, event: dto, accountEmail: eventAccountEmail)
                    if let newId = created.id {
                        event.googleEventId = newId
                    }
                    event.calendarId = calId
                    event.etag = created.etag
                    event.googleUpdatedAt = created.updated
                    if let hangout = created.hangoutLink {
                        event.conferenceURL = hangout
                        event.conferenceName = "Google Meet"
                    } else if let videoEntry = created.conferenceData?.entryPoints?.first(where: { $0.entryPointType == "video" }) {
                        event.conferenceURL = videoEntry.uri
                        event.conferenceName = created.conferenceData?.conferenceSolution?.name ?? "Google Meet"
                    }
                    if let attendees = created.attendees, !attendees.isEmpty {
                        event.attendeesJSON = Self.encodeAttendees(created.attendees)
                    }
                } else {
                    let sendUpdates = sendUpdatesOverrides.removeValue(forKey: event.googleEventId)
                    do {
                        let updated = try await calendarService.updateEvent(
                            calendarId: calId,
                            eventId: event.googleEventId,
                            event: dto,
                            etag: event.etag,
                            sendUpdates: sendUpdates,
                            accountEmail: eventAccountEmail
                        )
                        event.etag = updated.etag
                        event.googleUpdatedAt = updated.updated
                    } catch let conflictError as APIError where conflictError.isConflict {
                        MadoLogger.sync.warning("etag conflict for '\(event.title, privacy: .public)' — retrying without etag")
                        let updated = try await calendarService.updateEvent(
                            calendarId: calId,
                            eventId: event.googleEventId,
                            event: dto,
                            etag: nil,
                            sendUpdates: sendUpdates,
                            accountEmail: eventAccountEmail
                        )
                        event.etag = updated.etag
                        event.googleUpdatedAt = updated.updated
                    }
                }
                event.needsSync = false
            } catch let error as APIError where error == .notFound || error == .gone {
                event.needsSync = false
                event.isDeleted = true
            } catch let error as APIError {
                if case .httpError(let code, _) = error, (400...499).contains(code), code != 401 {
                    MadoLogger.sync.error("pushEvent rejected (\(code)) for '\(event.title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
                    event.needsSync = false
                } else {
                    MadoLogger.sync.error("pushEvent failed for '\(event.title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
                }
            } catch {
                MadoLogger.sync.error("pushEvent failed for '\(event.title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            }
        }
        data.save()
    }


    // MARK: - Pull Gmail Starred → Tasks

    private func pullGmailStarred() async throws {
        let starredRefs = try await gmailService.listStarredMessages()
        let starredMsgIds = Set(starredRefs.map(\.id))
        // Build message-to-thread mapping from API response
        let msgToThread = Dictionary(uniqueKeysWithValues: starredRefs.map { ($0.id, $0.threadId ?? $0.id) })

        // Part 1: Auto-complete tasks whose star was removed in Gmail.
        // NEVER reopen completed tasks — local "done" state is authoritative.
        // Push will handle unstarring; Gmail API lag would cause false reopens.
        let linkedTasks = try data.fetchTasksWithGmailLink()
        for task in linkedTasks {
            guard let msgId = task.gmailMessageId else { continue }
            guard !task.needsSync else { continue }
            // Backfill threadId if missing
            if task.gmailThreadId == nil, let threadId = msgToThread[msgId] {
                task.gmailThreadId = threadId
            }

            // Only auto-complete if star was removed — never reopen
            if !starredMsgIds.contains(msgId) && !task.isCompleted {
                task.isCompleted = true
                task.completedAt = Date()
                task.localUpdatedAt = Date()
                task.needsSync = false
            }
        }
        // Part 2: Create tasks for new starred THREADS (deduplicated)
        // Use ALL gmail-linked tasks (including completed/deleted) for dedup
        let allGmailTasks = try data.fetchAllGmailLinkedTasks()

        // Build set of known threadIds from stored data + current API response
        var existingThreadIds = Set<String>()
        for task in allGmailTasks {
            if let tid = task.gmailThreadId {
                existingThreadIds.insert(tid)
            }
            // Also map via current API data for tasks without stored threadId
            if let msgId = task.gmailMessageId, let threadId = msgToThread[msgId] {
                existingThreadIds.insert(threadId)
                // Backfill threadId if missing
                if task.gmailThreadId == nil {
                    task.gmailThreadId = threadId
                }
            }
        }

        // Group starred messages by thread
        let threadGroups = Dictionary(grouping: starredRefs, by: { $0.threadId ?? $0.id })
        for (threadId, msgs) in threadGroups {
            // Skip if this thread already has ANY linked task
            if existingThreadIds.contains(threadId) { continue }
            // Pick the first message as the representative for this thread
            guard let representative = msgs.first else { continue }
            do {
                let metadata = try await gmailService.getMessageMetadata(messageId: representative.id)
                let subject = metadata.subject ?? "(No subject)"
                let sender = metadata.senderName
                let snippet = metadata.snippet
                var notes = ""
                if let sender { notes += "From: \(sender)\n" }
                if let snippet, !snippet.isEmpty { notes += snippet }
                let task = MadoTask(
                    title: subject,
                    notes: notes.isEmpty ? nil : notes,
                    gmailMessageId: representative.id,
                    gmailThreadId: threadId
                )
                task.needsSync = false
                data.createTask(task)
                // Track this thread immediately to prevent duplicates within this batch
                existingThreadIds.insert(threadId)
            } catch {
                MadoLogger.sync.error("Failed to fetch Gmail message \(representative.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        data.save()
    }

    // MARK: - Push Task State → Gmail Stars

    private func pushGmailStars() async throws {
        let linkedTasks = try data.fetchTasksWithGmailLink()

        for task in linkedTasks {
            guard let msgId = task.gmailMessageId else { continue }
            guard task.needsSync else { continue }

            do {
                if task.isCompleted {
                    try await gmailService.unstarMessage(messageId: msgId)
                } else {
                    try await gmailService.starMessage(messageId: msgId)
                }
                task.needsSync = false
            } catch {
                MadoLogger.sync.error("Gmail star sync failed for '\(task.title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            }
        }
        data.save()
    }

    // MARK: - Helpers

    private static func encodeAttendees(_ dtos: [GoogleAttendeeDTO]?) -> Data? {
        guard let dtos, !dtos.isEmpty else { return nil }
        let attendees = dtos.map { dto in
            EventAttendee(
                email: dto.email ?? "",
                displayName: dto.displayName,
                responseStatus: dto.responseStatus ?? "needsAction",
                isOrganizer: dto.organizer ?? false,
                isSelf: dto.`self` ?? false
            )
        }
        return try? JSONEncoder().encode(attendees)
    }
}

// MARK: - APIError Equatable conformance for pattern matching
extension APIError: Equatable {
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated),
             (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.rateLimited, .rateLimited),
             (.notFound, .notFound),
             (.gone, .gone):
            return true
        case (.conflict(let a), .conflict(let b)):
            return a == b
        case (.httpError(let codeA, let msgA), .httpError(let codeB, let msgB)):
            return codeA == codeB && msgA == msgB
        default:
            return false
        }
    }
}

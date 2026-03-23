import Foundation
import os
import UserNotifications
import SwiftData

struct NotificationEntry: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    let type: String
    let referenceId: String
    let fireDate: Date
    let createdAt: Date
    var isRead: Bool

    init(title: String, body: String, type: String, referenceId: String, fireDate: Date) {
        self.id = UUID().uuidString
        self.title = title
        self.body = body
        self.type = type
        self.referenceId = referenceId
        self.fireDate = fireDate
        self.createdAt = Date()
        self.isRead = false
    }
}

@MainActor
@Observable
final class NotificationManager {
    private enum Constants {
        static let maxEntries = 50
        static let maxUpcomingReminders = 30
        static let entryCutoffDays = -7
    }

    static let shared = NotificationManager()

    var isAuthorized = false
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var entries: [NotificationEntry] = []

    var unreadCount: Int { entries.filter { !$0.isRead && $0.fireDate <= Date() }.count }

    private let center = UNUserNotificationCenter.current()
    private let settings = AppSettings.shared
    private let entriesKey = "notificationEntries"

    private init() {
        loadEntries()
        Task {
            await checkAuthorizationStatus()
            await importDeliveredNotifications()
        }
    }

    func importDeliveredNotifications() async {
        let delivered = await center.deliveredNotifications()
        let existingRefs = Set(entries.map { $0.referenceId })
        var added = false
        for notif in delivered {
            let userInfo = notif.request.content.userInfo
            let type = userInfo["type"] as? String ?? "event"
            let refId: String
            if let eventId = userInfo["eventId"] as? String {
                refId = eventId
            } else if let taskId = userInfo["taskId"] as? String {
                refId = taskId
            } else {
                refId = notif.request.identifier
            }
            guard !existingRefs.contains(refId) else { continue }
            let entry = NotificationEntry(
                title: notif.request.content.title,
                body: notif.request.content.body,
                type: type,
                referenceId: refId,
                fireDate: notif.date
            )
            entries.insert(entry, at: 0)
            added = true
        }
        if added {
            entries.sort { $0.fireDate > $1.fireDate }
            if entries.count > Constants.maxEntries { entries = Array(entries.prefix(Constants.maxEntries)) }
            saveEntries()
        }
    }

    // MARK: - Entry Persistence

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([NotificationEntry].self, from: data) else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: Constants.entryCutoffDays, to: Date()) ?? Date()
        entries = decoded.filter { $0.fireDate > cutoff }
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    func addEntry(_ entry: NotificationEntry) {
        if let idx = entries.firstIndex(where: { $0.referenceId == entry.referenceId && $0.type == entry.type }) {
            entries[idx] = entry
        } else {
            entries.insert(entry, at: 0)
        }
        if entries.count > Constants.maxEntries { entries = Array(entries.prefix(Constants.maxEntries)) }
        saveEntries()
    }

    func markRead(_ id: String) {
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx].isRead = true
            saveEntries()
            syncBadge()
        }
    }

    func markAllRead() {
        for i in entries.indices { entries[i].isRead = true }
        saveEntries()
        syncBadge()
    }

    func clearAll() {
        entries.removeAll()
        saveEntries()
        syncBadge()
    }

    // MARK: - Permission

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            await checkAuthorizationStatus()
        } catch {
            MadoLogger.notifications.error("Authorization error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Event Notifications

    /// Schedule a reminder notification for a calendar event.
    /// Uses `defaultReminderMinutes` from settings unless overridden.
    func scheduleEventReminder(_ event: CalendarEvent, minutesBefore: Int? = nil) {
        let calendarEnabled = (try? DataController.shared.fetchCalendars().first(where: { $0.googleCalendarId == event.calendarId }))?.notificationsEnabled ?? false
        guard calendarEnabled else { return }

        let reminderMinutes = minutesBefore ?? settings.defaultReminderMinutes
        guard reminderMinutes > 0 else { return }

        let fireDate = event.startDate.addingTimeInterval(-Double(reminderMinutes * 60))
        guard fireDate > Date() else { return }

        let body = formatEventReminderBody(event, minutesBefore: reminderMinutes)

        addEntry(NotificationEntry(
            title: event.title,
            body: body,
            type: "event",
            referenceId: event.googleEventId,
            fireDate: fireDate
        ))

        guard isAuthorized, settings.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "EVENT_REMINDER"
        content.userInfo = ["eventId": event.googleEventId, "type": "event"]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "event-\(event.id)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                MadoLogger.notifications.error("Failed to schedule event reminder: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Cancel a previously scheduled event notification.
    func cancelEventReminder(_ event: CalendarEvent) {
        center.removePendingNotificationRequests(withIdentifiers: ["event-\(event.id)"])
    }

    /// Schedule reminders for all upcoming events (call after sync or app launch).
    func rescheduleAllEventReminders(_ events: [CalendarEvent]) {
        let enabledCalendarIds: Set<String> = {
            let calendars = (try? DataController.shared.fetchCalendars()) ?? []
            return Set(calendars.filter(\.notificationsEnabled).map(\.googleCalendarId))
        }()
        entries.removeAll { $0.type == "event" && !enabledCalendarIds.contains($0.referenceId) }
        saveEntries()

        center.getPendingNotificationRequests { [weak self] requests in
            let eventIds = requests.filter { $0.identifier.hasPrefix("event-") }.map(\.identifier)
            self?.center.removePendingNotificationRequests(withIdentifiers: eventIds)

            Task { @MainActor in
                guard let self else { return }
                let upcoming = events
                    .filter { !$0.isDeleted && $0.startDate > Date() }
                    .sorted { $0.startDate < $1.startDate }
                    .prefix(Constants.maxUpcomingReminders)

                for event in upcoming {
                    self.scheduleEventReminder(event)
                }
            }
        }
    }

    // MARK: - Task Notifications

    func scheduleTaskReminder(_ task: MadoTask) {
        guard !task.isCompleted else { return }
        guard let fireDate = task.reminderDate ?? task.dueDate else { return }
        guard fireDate > Date() else { return }

        addEntry(NotificationEntry(
            title: "Task Due",
            body: task.title,
            type: "task",
            referenceId: task.id,
            fireDate: fireDate
        ))

        guard isAuthorized, settings.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task Due"
        content.body = task.title
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = ["taskId": task.id, "type": "task"]

        if task.priority == .high {
            content.interruptionLevel = .timeSensitive
        }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "task-\(task.id)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                MadoLogger.notifications.error("Failed to schedule task reminder: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Cancel a task's notification (e.g., when completed or deleted).
    func cancelTaskReminder(_ task: MadoTask) {
        center.removePendingNotificationRequests(withIdentifiers: ["task-\(task.id)"])
    }

    /// Reschedule all task reminders (call on app launch).
    func rescheduleAllTaskReminders(_ tasks: [MadoTask]) {
        center.getPendingNotificationRequests { [weak self] requests in
            let taskIds = requests.filter { $0.identifier.hasPrefix("task-") }.map(\.identifier)
            self?.center.removePendingNotificationRequests(withIdentifiers: taskIds)

            Task { @MainActor in
                guard let self else { return }
                let upcoming = tasks
                    .filter { !$0.isCompleted && !$0.isDeleted && ($0.reminderDate ?? $0.dueDate) != nil }
                    .sorted { ($0.reminderDate ?? $0.dueDate ?? .distantFuture) < ($1.reminderDate ?? $1.dueDate ?? .distantFuture) }
                    .prefix(Constants.maxUpcomingReminders)

                for task in upcoming {
                    self.scheduleTaskReminder(task)
                }
            }
        }
    }

    // MARK: - Overdue Tasks

    func updateOverdueTasks(_ tasks: [MadoTask]) {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let overdue = tasks.filter { !$0.isCompleted && !$0.isDeleted && ($0.dueDate ?? .distantFuture) < startOfToday }

        let overdueRefs = Set(overdue.map { $0.id })
        entries.removeAll { $0.type == "overdue" && !overdueRefs.contains($0.referenceId) }

        for task in overdue {
            if !entries.contains(where: { $0.referenceId == task.id && $0.type == "overdue" }) {
                let entry = NotificationEntry(
                    title: "Overdue",
                    body: task.title,
                    type: "overdue",
                    referenceId: task.id,
                    fireDate: task.dueDate ?? startOfToday
                )
                entries.append(entry)
            }
        }

        entries.sort { $0.fireDate > $1.fireDate }
        if entries.count > Constants.maxEntries { entries = Array(entries.prefix(Constants.maxEntries)) }
        saveEntries()
        syncBadge()
    }

    // MARK: - Badge

    func syncBadge() {
        center.setBadgeCount(unreadCount)
    }

    func clearBadge() {
        center.setBadgeCount(0)
    }

    // MARK: - Morning Brief

    func scheduleMorningBrief(events: [CalendarEvent], tasks: [MadoTask]) {
        guard settings.morningBriefEnabled else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["morning-brief"])

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let todayEvents = events.filter { !$0.isDeleted && cal.isDate($0.startDate, inSameDayAs: today) }
        let todayTasks = tasks.filter { !$0.isCompleted && !$0.isDeleted && $0.dueDate != nil && cal.isDate($0.dueDate!, inSameDayAs: today) }
        let overdueTasks = tasks.filter { !$0.isCompleted && !$0.isDeleted && ($0.dueDate ?? .distantFuture) < today }

        let eventCount = todayEvents.count
        let taskCount = todayTasks.count
        let overdueCount = overdueTasks.count

        var bodyParts: [String] = []
        if eventCount > 0 {
            let firstEvent = todayEvents.sorted(by: { $0.startDate < $1.startDate }).first
            let timeFormatter = DateFormatters.time(use24Hour: settings.use24HourTime)
            if let first = firstEvent {
                bodyParts.append("\(eventCount) event\(eventCount == 1 ? "" : "s") — first at \(timeFormatter.string(from: first.startDate))")
            }
        }
        if taskCount > 0 {
            bodyParts.append("\(taskCount) task\(taskCount == 1 ? "" : "s") due")
        }
        if overdueCount > 0 {
            bodyParts.append("\(overdueCount) overdue")
        }
        if bodyParts.isEmpty {
            bodyParts.append("No events or tasks scheduled. Enjoy your day!")
        }

        let briefTitle = "Good morning \u{2600}\u{FE0F}"
        let briefBody = bodyParts.joined(separator: " · ")

        var components = cal.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 8
        components.minute = 0

        addEntry(NotificationEntry(
            title: briefTitle,
            body: briefBody,
            type: "brief",
            referenceId: "morning-brief",
            fireDate: cal.date(from: components) ?? tomorrow
        ))

        guard isAuthorized, settings.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = briefTitle
        content.body = briefBody
        content.sound = .default
        content.categoryIdentifier = "MORNING_BRIEF"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "morning-brief",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                MadoLogger.notifications.error("Failed to schedule morning brief: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Remove All

    func removeAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        clearBadge()
    }

    // MARK: - Helpers

    private func formatEventReminderBody(_ event: CalendarEvent, minutesBefore: Int) -> String {
        let timeStr = DateFormatters.time(use24Hour: AppSettings.shared.use24HourTime).string(from: event.startDate)

        let minuteLabel: String
        if minutesBefore >= 60 {
            let hours = minutesBefore / 60
            minuteLabel = hours == 1 ? "1 hour" : "\(hours) hours"
        } else {
            minuteLabel = "\(minutesBefore) min"
        }

        var body = "Starts in \(minuteLabel) at \(timeStr)"
        if let location = event.location, !location.isEmpty {
            body += " · \(location)"
        }
        return body
    }
}

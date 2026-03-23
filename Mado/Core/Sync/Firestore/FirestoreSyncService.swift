import Foundation

/// Syncs local-only data to Firestore for cross-device access.
///
/// What this syncs (data NOT already in Google APIs):
/// - Task metadata supplements: labelIds, priority, position, parentTaskId, recurrence
/// - Labels (TaskLabel)
/// - UserCalendar visibility preferences (isSelected)
/// - Notes (.md file content)
/// - App settings/preferences
///
/// What this does NOT sync (already via Google APIs):
/// - Task core data (title, notes, completed, dueDate) → Google Tasks API
/// - Calendar events → Google Calendar API
/// - Gmail starred → Gmail API
@MainActor
@Observable
final class FirestoreSyncService {
    static let shared = FirestoreSyncService()

    private(set) var lastSync: Date?
    private(set) var isSyncing = false
    private(set) var lastError: String?

    private let client = FirestoreClient.shared
    private let data = DataController.shared

    private init() {}

    /// Whether Firestore sync is available
    var isAvailable: Bool {
        FirestoreConfig.isConfigured
    }

    // MARK: - Full Sync

    /// Pull all data from Firestore then push local changes
    func syncAll() async {
        guard isAvailable else { return }
        guard !isSyncing else { return }

        guard let userId = currentUserId() else {
            lastError = "Not signed in"
            return
        }

        isSyncing = true
        lastError = nil

        do {
            try await pullLabels(userId: userId)
            try await pullTaskMeta(userId: userId)
            try await pullCalendarPrefs(userId: userId)
            try await pullNotes(userId: userId)
            try await pullSettings(userId: userId)

            try await pushLabels(userId: userId)
            try await pushTaskMeta(userId: userId)
            try await pushCalendarPrefs(userId: userId)
            try await pushNotes(userId: userId)
            try await pushSettings(userId: userId)

            lastSync = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            print("[FirestoreSync] syncAll failed: \(error)")
        }

        isSyncing = false
    }

    /// Push only — for quick saves after local changes
    func pushAll() async {
        guard isAvailable else { return }
        guard let userId = currentUserId() else { return }

        do {
            try await pushLabels(userId: userId)
            try await pushTaskMeta(userId: userId)
            try await pushCalendarPrefs(userId: userId)
            try await pushNotes(userId: userId)
            try await pushSettings(userId: userId)
        } catch {
            print("[FirestoreSync] pushAll failed: \(error)")
        }
    }

    // MARK: - Labels

    private func pullLabels(userId: String) async throws {
        let path = "\(FirestoreConfig.userPath(userId: userId))/labels"
        let docs = try await client.listDocuments(collectionPath: path)
        let localLabels = try data.fetchLabels()
        let localById = Dictionary(uniqueKeysWithValues: localLabels.map { ($0.id, $0) })

        for doc in docs {
            guard let docId = doc.documentId, let fields = doc.fields else { continue }

            if let local = localById[docId] {
                // Update existing
                if let name = fields["name"]?.stringValue { local.name = name }
                if let color = fields["colorRaw"]?.stringValue { local.colorRaw = color }
                if let pos = fields["position"]?.intValue { local.position = pos }
            } else {
                // Create new from remote
                let label = TaskLabel(
                    id: docId,
                    name: fields["name"]?.stringValue ?? "Untitled",
                    color: LabelColor(rawValue: fields["colorRaw"]?.stringValue ?? "gray") ?? .gray,
                    position: fields["position"]?.intValue ?? 0
                )
                data.createLabel(label)
            }
        }
        data.save()
    }

    private func pushLabels(userId: String) async throws {
        let labels = try data.fetchLabels()
        var writes: [FirestoreBatchWrite] = []

        for label in labels {
            let docPath = "\(FirestoreConfig.baseURL)/users/\(userId)/labels/\(label.id)"
            let fields: [String: FirestoreValue] = [
                "name": .string(label.name),
                "colorRaw": .string(label.colorRaw),
                "position": .integer(label.position),
                "updatedAt": .timestamp(ISO8601DateFormatter().string(from: Date())),
            ]
            writes.append(.upsert(path: docPath, fields: fields))
        }

        // Batch in groups of 500 (Firestore limit)
        for chunk in writes.chunked(size: 500) {
            try await client.batchWrite(writes: chunk)
        }
    }

    // MARK: - Task Metadata (supplements to Google Tasks)

    private func pullTaskMeta(userId: String) async throws {
        let path = "\(FirestoreConfig.userPath(userId: userId))/taskMeta"
        let docs = try await client.listDocuments(collectionPath: path)

        for doc in docs {
            guard let docId = doc.documentId, let fields = doc.fields else { continue }

            // Find the local task by ID
            let descriptor = FetchDescriptor<MadoTask>(
                predicate: #Predicate { task in task.id == docId }
            )
            guard let task = try data.mainContext.fetch(descriptor).first else { continue }

            // Only update if remote is newer
            let remoteUpdated = fields["updatedAt"]?.stringValue
                .flatMap { ISO8601DateFormatter().date(from: $0) }
            if let remoteDate = remoteUpdated, remoteDate <= task.localUpdatedAt {
                continue
            }

            if let labelIds = fields["labelIds"]?.arrayValue {
                task.labelIds = labelIds.compactMap { $0.stringValue }
            }
            if let priority = fields["priority"]?.intValue {
                task.priority = TaskPriority(rawValue: priority) ?? TaskPriority.none
            }
            if let position = fields["position"]?.intValue {
                task.position = position
            }
            if let parentId = fields["parentTaskId"]?.stringValue {
                task.parentTaskId = parentId.isEmpty ? nil : parentId
            }
            if let recurrenceData = fields["recurrenceData"]?.stringValue,
               let decoded = Data(base64Encoded: recurrenceData) {
                task.recurrenceRuleData = decoded
            }
        }
        data.save()
    }

    private func pushTaskMeta(userId: String) async throws {
        let tasks = try data.fetchTasks()
        var writes: [FirestoreBatchWrite] = []

        for task in tasks {
            let docPath = "\(FirestoreConfig.baseURL)/users/\(userId)/taskMeta/\(task.id)"
            var fields: [String: FirestoreValue] = [
                "priority": .integer(task.priority.rawValue),
                "position": .integer(task.position),
                "updatedAt": .timestamp(ISO8601DateFormatter().string(from: task.localUpdatedAt)),
            ]

            // Label IDs array
            if !task.labelIds.isEmpty {
                fields["labelIds"] = .array(task.labelIds.map { .string($0) })
            } else {
                fields["labelIds"] = .array([])
            }

            // Optional fields
            if let parentId = task.parentTaskId {
                fields["parentTaskId"] = .string(parentId)
            } else {
                fields["parentTaskId"] = .string("")
            }

            if let recurrenceData = task.recurrenceRuleData {
                fields["recurrenceData"] = .string(recurrenceData.base64EncodedString())
            }

            writes.append(.upsert(path: docPath, fields: fields))
        }

        for chunk in writes.chunked(size: 500) {
            try await client.batchWrite(writes: chunk)
        }
    }

    // MARK: - Calendar Preferences

    private func pullCalendarPrefs(userId: String) async throws {
        let path = "\(FirestoreConfig.userPath(userId: userId))/calendarPrefs"
        let docs = try await client.listDocuments(collectionPath: path)
        let localCals = try data.fetchCalendars()
        let localById = Dictionary(uniqueKeysWithValues: localCals.map { ($0.googleCalendarId, $0) })

        for doc in docs {
            guard let docId = doc.documentId, let fields = doc.fields else { continue }
            guard let cal = localById[docId] else { continue }

            if let isSelected = fields["isSelected"]?.boolValue {
                cal.isSelected = isSelected
            }
        }
        data.save()
    }

    private func pushCalendarPrefs(userId: String) async throws {
        let cals = try data.fetchCalendars()
        var writes: [FirestoreBatchWrite] = []

        for cal in cals {
            let safeId = cal.googleCalendarId.replacingOccurrences(of: "/", with: "_")
            let docPath = "\(FirestoreConfig.baseURL)/users/\(userId)/calendarPrefs/\(safeId)"
            let fields: [String: FirestoreValue] = [
                "googleCalendarId": .string(cal.googleCalendarId),
                "isSelected": .boolean(cal.isSelected),
                "name": .string(cal.name),
            ]
            writes.append(.upsert(path: docPath, fields: fields))
        }

        for chunk in writes.chunked(size: 500) {
            try await client.batchWrite(writes: chunk)
        }
    }

    // MARK: - Notes

    private func pullNotes(userId: String) async throws {
        let path = "\(FirestoreConfig.userPath(userId: userId))/notes"
        let docs = try await client.listDocuments(collectionPath: path)
        let noteManager = NoteFileManager.shared

        for doc in docs {
            guard let fields = doc.fields else { continue }
            guard let fileName = fields["fileName"]?.stringValue,
                  let content = fields["content"]?.stringValue else { continue }

            let remoteUpdated = fields["updatedAt"]?.stringValue
                .flatMap { ISO8601DateFormatter().date(from: $0) }

            // Check if file exists locally
            let fileURL = noteManager.vaultURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // Only overwrite if remote is newer
                let localModified = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let remoteDate = remoteUpdated, let localDate = localModified, remoteDate <= localDate {
                    continue
                }
            }

            // Write remote content to local file
            let dir = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        noteManager.loadFiles()
    }

    private func pushNotes(userId: String) async throws {
        let noteManager = NoteFileManager.shared
        let files = noteManager.flatFiles()
        var writes: [FirestoreBatchWrite] = []
        let formatter = ISO8601DateFormatter()

        for file in files {
            let content = noteManager.readFile(file)
            // Use relative path as document ID (sanitized for Firestore)
            let safeId = file.id.replacingOccurrences(of: "/", with: "__")
                .replacingOccurrences(of: ".", with: "_")
            let docPath = "\(FirestoreConfig.baseURL)/users/\(userId)/notes/\(safeId)"
            let fields: [String: FirestoreValue] = [
                "fileName": .string(file.id),
                "displayName": .string(file.displayName),
                "content": .string(content),
                "updatedAt": .timestamp(formatter.string(from: file.modifiedDate)),
            ]
            writes.append(.upsert(path: docPath, fields: fields))
        }

        for chunk in writes.chunked(size: 500) {
            try await client.batchWrite(writes: chunk)
        }
    }

    // MARK: - Settings

    private func pullSettings(userId: String) async throws {
        let docPath = "\(FirestoreConfig.userPath(userId: userId))/settings/preferences"
        guard let doc = try await client.getDocument(path: docPath),
              let fields = doc.fields else { return }

        let settings = AppSettings.shared

        if let v = fields["startOfWeek"]?.intValue { settings.startOfWeek = v }
        if let v = fields["use24HourTime"]?.boolValue { settings.use24HourTime = v }
        if let v = fields["showWeekends"]?.boolValue { settings.showWeekends = v }
        if let v = fields["showWeekNumbers"]?.boolValue { settings.showWeekNumbers = v }
        if let v = fields["defaultEventDuration"]?.intValue { settings.defaultEventDuration = v }
        if let v = fields["defaultReminderMinutes"]?.intValue { settings.defaultReminderMinutes = v }
        if let v = fields["workingHoursStart"]?.intValue { settings.workingHoursStart = v }
        if let v = fields["workingHoursEnd"]?.intValue { settings.workingHoursEnd = v }
        if let v = fields["showDeclinedEvents"]?.boolValue { settings.showDeclinedEvents = v }
        if let v = fields["syncIntervalMinutes"]?.doubleValue { settings.syncIntervalMinutes = v }
        if let v = fields["gmailSyncEnabled"]?.boolValue { settings.gmailSyncEnabled = v }
        if let v = fields["notificationsEnabled"]?.boolValue { settings.notificationsEnabled = v }
        if let v = fields["morningBriefEnabled"]?.boolValue { settings.morningBriefEnabled = v }
    }

    private func pushSettings(userId: String) async throws {
        let settings = AppSettings.shared
        let docPath = "\(FirestoreConfig.userPath(userId: userId))/settings/preferences"

        let fields: [String: FirestoreValue] = [
            "startOfWeek": .integer(settings.startOfWeek),
            "use24HourTime": .boolean(settings.use24HourTime),
            "showWeekends": .boolean(settings.showWeekends),
            "showWeekNumbers": .boolean(settings.showWeekNumbers),
            "defaultEventDuration": .integer(settings.defaultEventDuration),
            "defaultReminderMinutes": .integer(settings.defaultReminderMinutes),
            "workingHoursStart": .integer(settings.workingHoursStart),
            "workingHoursEnd": .integer(settings.workingHoursEnd),
            "showDeclinedEvents": .boolean(settings.showDeclinedEvents),
            "syncIntervalMinutes": .double(settings.syncIntervalMinutes),
            "gmailSyncEnabled": .boolean(settings.gmailSyncEnabled),
            "notificationsEnabled": .boolean(settings.notificationsEnabled),
            "morningBriefEnabled": .boolean(settings.morningBriefEnabled),
            "updatedAt": .timestamp(ISO8601DateFormatter().string(from: Date())),
        ]

        try await client.setDocument(path: docPath, fields: fields)
    }

    // MARK: - Helpers

    private func currentUserId() -> String? {
        guard let email = AuthenticationManager.shared.status.userEmail else { return nil }
        return FirestoreConfig.sanitizeUserId(email)
    }
}

// MARK: - Array Chunking Helper

import SwiftData

extension Array {
    func chunked(size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

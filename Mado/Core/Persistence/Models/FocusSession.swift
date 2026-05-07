import Foundation
import SwiftData

@Model
final class FocusSession {
    @Attribute(.unique) var id: String = UUID().uuidString

    // Linked task (optional — nil for Quick Focus)
    var taskId: String?

    // Timing
    var startTime: Date = Date()
    var endTime: Date?
    var durationSeconds: Int = 0

    // State
    var isCompleted: Bool = false
    var sessionNumber: Int = 1
    var breakDurationSeconds: Int = 0

    // Optional post-session note
    var note: String?

    // Sync
    var needsFirestoreSync: Bool = true
    var createdAt: Date = Date()

    init(
        id: String = UUID().uuidString,
        taskId: String? = nil,
        startTime: Date = Date(),
        durationSeconds: Int = 0,
        sessionNumber: Int = 1,
        breakDurationSeconds: Int = 0
    ) {
        self.id = id
        self.taskId = taskId
        self.startTime = startTime
        self.durationSeconds = durationSeconds
        self.sessionNumber = sessionNumber
        self.breakDurationSeconds = breakDurationSeconds
        self.createdAt = Date()
        self.needsFirestoreSync = true
    }

    func markCompleted(endTime: Date = Date()) {
        self.isCompleted = true
        self.endTime = endTime
        self.durationSeconds = Int(endTime.timeIntervalSince(startTime))
        self.needsFirestoreSync = true
    }
}

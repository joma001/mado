import Foundation
import SwiftData
import UniformTypeIdentifiers
import CoreTransferable

// MARK: - Priority
enum TaskPriority: Int, Codable, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var label: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var sortOrder: Int { rawValue }
}

// MARK: - Recurrence Rule
enum RecurrenceFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

    var label: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

struct RecurrenceRule: Codable, Equatable {
    var frequency: RecurrenceFrequency
    var interval: Int // e.g., every 2 weeks
    var endDate: Date?

    static let daily = RecurrenceRule(frequency: .daily, interval: 1)
    static let weekly = RecurrenceRule(frequency: .weekly, interval: 1)
    static let monthly = RecurrenceRule(frequency: .monthly, interval: 1)
}

// MARK: - MadoTask SwiftData Model
@Model
final class MadoTask {
    // Identifiers
    @Attribute(.unique) var id: String = UUID().uuidString
    var googleTaskId: String?
    var googleTaskListId: String?

    // Content
    var title: String = ""
    var notes: String?

    // Status
    var isCompleted: Bool = false
    var completedAt: Date?

    // Scheduling
    var dueDate: Date?
    var reminderDate: Date?
    var priority: TaskPriority = TaskPriority.none

    // Organization
    var labelIds: [String] = []
    var position: Int = 0

    // Subtasks
    var parentTaskId: String?

    var projectId: String?

    // Recurrence
    var recurrenceRuleData: Data?

    // Sync metadata
    var googleUpdatedAt: Date?
    var localUpdatedAt: Date = Date()
    var createdAt: Date = Date()
    var isDeleted: Bool = false
    var needsSync: Bool = true


    // Gmail integration
    var gmailMessageId: String?
    var gmailThreadId: String?
    var recurrenceRule: RecurrenceRule? {
        get {
            guard let data = recurrenceRuleData else { return nil }
            return try? JSONDecoder().decode(RecurrenceRule.self, from: data)
        }
        set {
            recurrenceRuleData = try? JSONEncoder().encode(newValue)
        }
    }

    var isRecurring: Bool {
        recurrenceRule != nil
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        priority: TaskPriority = .none,
        labelIds: [String] = [],
        position: Int = 0,
        parentTaskId: String? = nil,
        googleTaskId: String? = nil,
        googleTaskListId: String? = nil,
        projectId: String? = nil,
        gmailMessageId: String? = nil,
        gmailThreadId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.completedAt = nil
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.priority = priority
        self.labelIds = labelIds
        self.position = position
        self.parentTaskId = parentTaskId
        self.googleTaskId = googleTaskId
        self.googleTaskListId = googleTaskListId
        self.projectId = projectId
        self.gmailMessageId = gmailMessageId
        self.gmailThreadId = gmailThreadId
        self.localUpdatedAt = Date()
        self.createdAt = Date()
        self.isDeleted = false
        self.needsSync = true
    }

    func markCompleted() {
        isCompleted = true
        completedAt = Date()
        localUpdatedAt = Date()
        needsSync = true
    }

    func markIncomplete() {
        isCompleted = false
        completedAt = nil
        localUpdatedAt = Date()
        needsSync = true
    }

    func markUpdated() {
        localUpdatedAt = Date()
        needsSync = true
    }
}

// MARK: - Transferable for Drag & Drop
extension UTType {
    static let madoTask = UTType(exportedAs: "com.mado.task")
}

struct TransferableTask: Codable, Transferable {
    let id: String
    let title: String
    let dueDate: Date?
    let priority: TaskPriority

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .madoTask)
    }

    init(from task: MadoTask) {
        self.id = task.id
        self.title = task.title
        self.dueDate = task.dueDate
        self.priority = task.priority
    }
}

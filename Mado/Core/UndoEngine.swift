import Foundation
import SwiftUI
import SwiftData

// MARK: - Undo Action Types

enum UndoActionKind: String {
    case taskCreated = "Task created"
    case taskDeleted = "Task deleted"
    case taskCompleted = "Task completed"
    case taskUncompleted = "Task uncompleted"
    case taskEdited = "Task edited"
    case taskMoved = "Task moved"
    case eventCreated = "Event created"
    case eventDeleted = "Event deleted"
    case eventEdited = "Event edited"
    case rsvpChanged = "RSVP updated"
}

/// Snapshot of a task's state before a change
struct TaskSnapshot {
    let id: String
    let title: String
    let isCompleted: Bool
    let completedAt: Date?
    let dueDate: Date?
    let priority: TaskPriority
    let notes: String?
    let projectId: String?
    let position: Int
    let isDeleted: Bool
    let labelIds: [String]

    init(from task: MadoTask) {
        self.id = task.id
        self.title = task.title
        self.isCompleted = task.isCompleted
        self.completedAt = task.completedAt
        self.dueDate = task.dueDate
        self.priority = task.priority
        self.notes = task.notes
        self.projectId = task.projectId
        self.position = task.position
        self.isDeleted = task.isDeleted
        self.labelIds = task.labelIds
    }

    @MainActor
    func restore(to task: MadoTask) {
        task.title = title
        task.isCompleted = isCompleted
        task.completedAt = completedAt
        task.dueDate = dueDate
        task.priority = priority
        task.notes = notes
        task.projectId = projectId
        task.position = position
        task.isDeleted = isDeleted
        task.labelIds = labelIds
        task.needsSync = true
        task.localUpdatedAt = Date()
    }
}

/// Snapshot of an event's state before a change
struct EventSnapshot {
    let googleEventId: String
    let calendarId: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let isDeleted: Bool
    let attendeesJSON: Data?

    init(from event: CalendarEvent) {
        self.googleEventId = event.googleEventId
        self.calendarId = event.calendarId
        self.title = event.title
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.isAllDay = event.isAllDay
        self.location = event.location
        self.notes = event.notes
        self.isDeleted = event.isDeleted
        self.attendeesJSON = event.attendeesJSON
    }

    @MainActor
    func restore(to event: CalendarEvent) {
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.location = location
        event.notes = notes
        event.isDeleted = isDeleted
        event.attendeesJSON = attendeesJSON
        event.needsSync = true
    }
}

/// A recorded undoable action
struct UndoAction {
    let kind: UndoActionKind
    let message: String
    let undo: @MainActor () -> Void
    let timestamp = Date()
}

// MARK: - Undo Engine

@MainActor
@Observable
final class UndoEngine {
    static let shared = UndoEngine()

    /// Currently visible toast (nil = hidden)
    var currentToast: UndoToastData?

    /// Stack of undo actions (most recent first)
    private var undoStack: [UndoAction] = []
    private var dismissTask: Task<Void, Never>?

    private let data = DataController.shared
    private let sync = SyncEngine.shared

    private init() {}

    // MARK: - Record & Show

    func record(_ action: UndoAction) {
        undoStack.insert(action, at: 0)
        // Keep stack bounded
        if undoStack.count > 50 { undoStack.removeLast() }

        showToast(message: action.message, kind: action.kind)

        #if os(macOS)
        registerWithNSUndoManager(action)
        #endif
    }

    // MARK: - Perform Undo

    func undoLast() {
        guard let action = undoStack.first else { return }
        undoStack.removeFirst()
        action.undo()
        data.save()
        sync.schedulePush()
        hideToast()
    }

    // MARK: - Toast

    private func showToast(message: String, kind: UndoActionKind) {
        dismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = UndoToastData(message: message, kind: kind)
        }
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            hideToast()
        }
    }

    func hideToast() {
        dismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = nil
        }
    }

    // MARK: - macOS Cmd+Z Integration

    #if os(macOS)
    private func registerWithNSUndoManager(_ action: UndoAction) {
        guard let undoManager = NSApp.windows.first?.undoManager else { return }
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            Task { @MainActor in
                self?.undoLast()
            }
        }
        undoManager.setActionName(action.kind.rawValue)
    }
    #endif

    // MARK: - Convenience: Task Actions

    func recordTaskCreated(_ task: MadoTask) {
        let taskId = task.id
        record(UndoAction(
            kind: .taskCreated,
            message: "Task created",
            undo: { [weak self] in
                guard let self else { return }
                if let task = try? self.data.mainContext.fetch(
                    FetchDescriptor<MadoTask>(predicate: #Predicate { $0.id == taskId })
                ).first {
                    task.isDeleted = true
                    task.needsSync = true
                }
            }
        ))
    }

    func recordTaskDeleted(_ task: MadoTask) {
        let snapshot = TaskSnapshot(from: task)
        let taskId = task.id
        record(UndoAction(
            kind: .taskDeleted,
            message: "\"\(task.title)\" deleted",
            undo: { [weak self] in
                guard let self else { return }
                if let task = try? self.data.mainContext.fetch(
                    FetchDescriptor<MadoTask>(predicate: #Predicate { $0.id == taskId })
                ).first {
                    snapshot.restore(to: task)
                }
            }
        ))
    }

    func recordTaskToggled(_ task: MadoTask, wasCompleted: Bool) {
        let taskId = task.id
        let kind: UndoActionKind = wasCompleted ? .taskUncompleted : .taskCompleted
        let msg = wasCompleted ? "Task marked incomplete" : "Task completed"
        let prevCompletedAt = task.completedAt
        record(UndoAction(
            kind: kind,
            message: msg,
            undo: { [weak self] in
                guard let self else { return }
                if let task = try? self.data.mainContext.fetch(
                    FetchDescriptor<MadoTask>(predicate: #Predicate { $0.id == taskId })
                ).first {
                    task.isCompleted = wasCompleted
                    task.completedAt = prevCompletedAt
                    task.needsSync = true
                    task.localUpdatedAt = Date()
                }
            }
        ))
    }

    func recordTaskEdited(_ task: MadoTask, snapshot: TaskSnapshot) {
        let taskId = task.id
        record(UndoAction(
            kind: .taskEdited,
            message: "Task edited",
            undo: { [weak self] in
                guard let self else { return }
                if let task = try? self.data.mainContext.fetch(
                    FetchDescriptor<MadoTask>(predicate: #Predicate { $0.id == taskId })
                ).first {
                    snapshot.restore(to: task)
                }
            }
        ))
    }

    func recordTaskMoved(_ task: MadoTask, fromProjectId: String?) {
        let taskId = task.id
        let oldProjectId = fromProjectId
        record(UndoAction(
            kind: .taskMoved,
            message: "Task moved",
            undo: { [weak self] in
                guard let self else { return }
                if let task = try? self.data.mainContext.fetch(
                    FetchDescriptor<MadoTask>(predicate: #Predicate { $0.id == taskId })
                ).first {
                    task.projectId = oldProjectId
                    task.needsSync = true
                    task.localUpdatedAt = Date()
                }
            }
        ))
    }

    // MARK: - Convenience: Event Actions

    func recordEventCreated(_ event: CalendarEvent) {
        let eventId = event.googleEventId
        record(UndoAction(
            kind: .eventCreated,
            message: "Event created",
            undo: { [weak self] in
                guard let self else { return }
                if let event = try? self.data.mainContext.fetch(
                    FetchDescriptor<CalendarEvent>(predicate: #Predicate { $0.googleEventId == eventId })
                ).first {
                    event.isDeleted = true
                    event.needsSync = true
                }
            }
        ))
    }

    func recordEventDeleted(_ event: CalendarEvent) {
        let snapshot = EventSnapshot(from: event)
        let eventId = event.googleEventId
        record(UndoAction(
            kind: .eventDeleted,
            message: "\"\(event.title)\" deleted",
            undo: { [weak self] in
                guard let self else { return }
                if let event = try? self.data.mainContext.fetch(
                    FetchDescriptor<CalendarEvent>(predicate: #Predicate { $0.googleEventId == eventId })
                ).first {
                    snapshot.restore(to: event)
                }
            }
        ))
    }

    func recordEventEdited(_ event: CalendarEvent, snapshot: EventSnapshot) {
        let eventId = event.googleEventId
        record(UndoAction(
            kind: .eventEdited,
            message: "Event edited",
            undo: { [weak self] in
                guard let self else { return }
                if let event = try? self.data.mainContext.fetch(
                    FetchDescriptor<CalendarEvent>(predicate: #Predicate { $0.googleEventId == eventId })
                ).first {
                    snapshot.restore(to: event)
                }
            }
        ))
    }

    func recordRSVPChanged(_ event: CalendarEvent, previousJSON: Data?) {
        let eventId = event.googleEventId
        let oldJSON = previousJSON
        record(UndoAction(
            kind: .rsvpChanged,
            message: "RSVP updated",
            undo: { [weak self] in
                guard let self else { return }
                if let event = try? self.data.mainContext.fetch(
                    FetchDescriptor<CalendarEvent>(predicate: #Predicate { $0.googleEventId == eventId })
                ).first {
                    event.attendeesJSON = oldJSON
                    event.needsSync = true
                }
            }
        ))
    }
}

// MARK: - Toast Data

struct UndoToastData: Equatable {
    let id = UUID()
    let message: String
    let kind: UndoActionKind

    static func == (lhs: UndoToastData, rhs: UndoToastData) -> Bool {
        lhs.id == rhs.id
    }
}

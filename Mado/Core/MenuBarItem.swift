import Foundation

/// Unified item type for displaying events and tasks in time-based views.
/// Shared between macOS MenuBar and iOS Today tab.
enum MenuBarItem: Identifiable {
    case event(CalendarEvent)
    case task(MadoTask)

    var id: String {
        switch self {
        case .event(let e): return "event-\(e.id)"
        case .task(let t): return "task-\(t.id)"
        }
    }

    var sortDate: Date {
        switch self {
        case .event(let e): return e.startDate
        case .task(let t): return t.dueDate ?? Date.distantFuture
        }
    }
}

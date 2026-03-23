import Foundation
import SwiftData

@MainActor
@Observable
final class SearchManager {
    var query = ""
    var taskResults: [MadoTask] = []
    var eventResults: [CalendarEvent] = []
    var isSearching = false

    private let data = DataController.shared

    var hasResults: Bool {
        !taskResults.isEmpty || !eventResults.isEmpty
    }

    var totalCount: Int {
        taskResults.count + eventResults.count
    }

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            taskResults = []
            eventResults = []
            return
        }

        isSearching = true

        do {
            // Search tasks
            let allTasks = try data.fetchTasks(includeCompleted: true)
            taskResults = allTasks.filter { task in
                task.title.lowercased().contains(trimmed) ||
                (task.notes?.lowercased().contains(trimmed) ?? false)
            }
            .prefix(20)
            .map { $0 }

            // Search events
            let cal = Calendar.current
            let start = cal.date(byAdding: .month, value: -3, to: Date())!
            let end = cal.date(byAdding: .month, value: 6, to: Date())!
            let allEvents = try data.fetchEvents(from: start, to: end)
            eventResults = allEvents.filter { event in
                !event.isDeleted && (
                    event.title.lowercased().contains(trimmed) ||
                    (event.notes?.lowercased().contains(trimmed) ?? false) ||
                    (event.location?.lowercased().contains(trimmed) ?? false)
                )
            }
            .prefix(20)
            .map { $0 }
        } catch {
            taskResults = []
            eventResults = []
        }

        isSearching = false
    }

    func clear() {
        query = ""
        taskResults = []
        eventResults = []
    }
}

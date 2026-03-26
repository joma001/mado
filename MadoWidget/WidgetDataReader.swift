import Foundation

/// Reads and writes shared widget data via App Group container.
struct WidgetDataReader {
    static let appGroupID = "group.io.mado.mobile"

    private static func fileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget_data.json")
    }

    static func read() -> WidgetSharedData {
        guard let url = fileURL(),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: data) else {
            return .empty
        }
        return decoded
    }

    /// Toggles the `isCompleted` flag of the task with the given ID and persists the result.
    static func toggleTask(id: String) {
        guard let url = fileURL() else { return }
        let current = read()
        let updatedTasks = current.tasks.map { task -> WidgetTask in
            guard task.id == id else { return task }
            return WidgetTask(
                id: task.id,
                title: task.title,
                dueDate: task.dueDate,
                isCompleted: !task.isCompleted
            )
        }
        let updated = WidgetSharedData(
            events: current.events,
            tasks: updatedTasks,
            lastUpdated: Date()
        )
        if let encoded = try? JSONEncoder().encode(updated) {
            try? encoded.write(to: url, options: .atomic)
        }
    }
}

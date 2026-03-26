import AppIntents
import WidgetKit

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"

    @Parameter(title: "Task ID")
    var taskId: String

    init() {}

    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        WidgetDataReader.toggleTask(id: taskId)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

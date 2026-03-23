import Foundation
import SwiftUI

func debugLog(_ message: String) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let logMessage = "\(timestamp) \(message)\n"
    NSLog("%@", message)
    if let logFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("mado-debug.log") {
        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            handle.write(logMessage.data(using: .utf8) ?? Data())
            handle.closeFile()
        } else {
            try? logMessage.write(to: logFile, atomically: true, encoding: .utf8)
        }
    }
}


@MainActor
@Observable
final class TodoViewModel {
    var tasks: [MadoTask] = []
    var projects: [Project] = []
    var labels: [TaskLabel] = []
    var selectedTask: MadoTask?
    var searchText = ""
    var filterPriority: TaskPriority?
    var showCompleted = true
    var isLoading = false
    var selectedProjectId: String?

    private let data = DataController.shared
    private let sync = SyncEngine.shared
    private let undo = UndoEngine.shared
    private let notifications = NotificationManager.shared

    var filteredTasks: [MadoTask] {
        var result = tasks
        if !showCompleted {
            result = result.filter { !$0.isCompleted }
        }
        if let filterPriority {
            result = result.filter { $0.priority == filterPriority }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                ($0.notes?.lowercased().contains(query) ?? false)
            }
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        result.sort { a, b in
            let aToday = a.dueDate.map { $0 >= today && $0 < tomorrow } ?? false
            let bToday = b.dueDate.map { $0 >= today && $0 < tomorrow } ?? false
            if aToday != bToday { return aToday }
            let aPri = a.priority == .none ? 4 : (4 - a.priority.rawValue)
            let bPri = b.priority == .none ? 4 : (4 - b.priority.rawValue)
            if aPri != bPri { return aPri < bPri }
            return a.position < b.position
        }
        return result
    }

    var topLevelTasks: [MadoTask] {
        filteredTasks.filter { $0.parentTaskId == nil }
    }

    func tasksForProject(_ projectId: String?) -> [MadoTask] {
        topLevelTasks.filter { $0.projectId == projectId }
    }

    var inboxTasks: [MadoTask] {
        topLevelTasks.filter { $0.projectId == nil }
    }

    func loadTasks() {
        isLoading = true
        do {
            tasks = try data.fetchTasks()
            notifications.rescheduleAllTaskReminders(tasks)
            notifications.updateOverdueTasks(tasks)
        } catch {
            NSLog("[TodoViewModel] Load failed: %@", error.localizedDescription)
            tasks = []
        }
        isLoading = false
    }

    func loadProjects() {
        do {
            projects = try data.fetchProjects()
        } catch {
            projects = []
        }
    }

    func loadLabels() {
        do {
            labels = try data.fetchLabels()
        } catch {
            labels = []
        }
    }

    func loadAll() {
        data.deduplicateGmailTasks()
        loadTasks()
        loadProjects()
        loadLabels()
    }

    func addTask(title: String, projectId: String? = nil, dueDate: Date? = nil) {
        for t in tasks { t.position += 1 }
        let task = MadoTask(title: title, position: 0, projectId: projectId)
        task.dueDate = dueDate
        data.createTask(task)
        loadTasks()
        sync.schedulePush()
        undo.recordTaskCreated(task)
        notifications.scheduleTaskReminder(task)
    }

    func toggleTask(_ task: MadoTask) {
        let wasCompleted = task.isCompleted
        if task.isCompleted {
            task.markIncomplete()
            notifications.scheduleTaskReminder(task)
        } else {
            task.markCompleted()
            notifications.cancelTaskReminder(task)
        }
        data.save()
        sync.schedulePush()
        undo.recordTaskToggled(task, wasCompleted: wasCompleted)
        loadTasks()
    }

    func deleteTask(_ task: MadoTask) {
        undo.recordTaskDeleted(task)
        notifications.cancelTaskReminder(task)
        data.deleteTask(task)
        if selectedTask?.id == task.id {
            selectedTask = nil
        }
        loadTasks()
        sync.schedulePush()
    }

    func updateTask(_ task: MadoTask) {
        task.markUpdated()
        data.save()
        notifications.scheduleTaskReminder(task)
        sync.schedulePush()
    }

    func snoozeTask(_ task: MadoTask, to date: Date) {
        let snapshot = TaskSnapshot(from: task)
        task.dueDate = date
        task.markUpdated()
        data.save()
        notifications.scheduleTaskReminder(task)
        sync.schedulePush()
        undo.recordTaskEdited(task, snapshot: snapshot)
        loadTasks()
    }

    func moveTask(_ task: MadoTask, toProject projectId: String?) {
        let oldProjectId = task.projectId
        let oldListId = task.googleTaskListId
        task.projectId = projectId
        if let projectId, let project = projects.first(where: { $0.id == projectId }) {
            task.googleTaskListId = project.googleTaskListId
        } else {
            task.googleTaskListId = nil
        }
        if task.googleTaskId != nil && oldListId != nil && oldListId != task.googleTaskListId {
            sync.pendingListMoves[task.id] = oldListId!
        }
        task.markUpdated()
        data.save()
        loadTasks()
        sync.schedulePush()
        undo.recordTaskMoved(task, fromProjectId: oldProjectId)
    }

    func subtasks(for task: MadoTask) -> [MadoTask] {
        tasks.filter { $0.parentTaskId == task.id && !$0.isDeleted }
    }

    func addSubtask(to parent: MadoTask, title: String) {
        let subs = subtasks(for: parent)
        let task = MadoTask(
            title: title,
            position: subs.count,
            parentTaskId: parent.id,
            projectId: parent.projectId
        )
        data.createTask(task)
        loadTasks()
        sync.schedulePush()
    }

    func addProject(name: String, color: ProjectColor = .blue) {
        let project = Project(
            name: name,
            color: color,
            position: projects.count
        )
        data.createProject(project)
        loadProjects()
    }

    func deleteProject(_ project: Project) {
        let orphaned = tasksForProject(project.id)
        for task in orphaned {
            task.projectId = nil
            task.markUpdated()
        }
        data.deleteProject(project)
        loadProjects()
        loadTasks()
    }

    func renameProject(_ project: Project, to name: String) {
        project.name = name
        data.save()
        loadProjects()
    }

    func toggleProjectExpanded(_ project: Project) {
        project.isExpanded.toggle()
        data.save()
    }

}

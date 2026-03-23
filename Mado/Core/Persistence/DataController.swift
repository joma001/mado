import Foundation
import SwiftData
import SwiftUI

@MainActor
final class DataController {
    static let shared = DataController()

    let modelContainer: ModelContainer

    private init() {
        let schema = Schema([
            MadoTask.self,
            TaskLabel.self,
            CalendarEvent.self,
            UserCalendar.self,
            Project.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var mainContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Task CRUD

    func fetchTasks(
        includeCompleted: Bool = true,
        parentId: String? = nil
    ) throws -> [MadoTask] {
        var descriptor = FetchDescriptor<MadoTask>(
            predicate: #Predicate { task in
                task.isDeleted == false
            },
            sortBy: [
                SortDescriptor(\.position),
                SortDescriptor(\.createdAt),
            ]
        )
        return try mainContext.fetch(descriptor)
    }

    func fetchSubtasks(parentId: String) throws -> [MadoTask] {
        let descriptor = FetchDescriptor<MadoTask>(
            predicate: #Predicate { task in
                task.parentTaskId == parentId && task.isDeleted == false
            },
            sortBy: [SortDescriptor(\.position)]
        )
        return try mainContext.fetch(descriptor)
    }

    func createTask(_ task: MadoTask) {
        mainContext.insert(task)
        do {
            try mainContext.save()
        } catch {
            print("[DataController] createTask failed: \(error)")
        }
    }

    func deleteTask(_ task: MadoTask) {
        task.isDeleted = true
        task.needsSync = true
        task.localUpdatedAt = Date()
        save()
    }

    // MARK: - Label CRUD

    func fetchLabels() throws -> [TaskLabel] {
        let descriptor = FetchDescriptor<TaskLabel>(
            sortBy: [SortDescriptor(\.position)]
        )
        return try mainContext.fetch(descriptor)
    }

    func createLabel(_ label: TaskLabel) {
        mainContext.insert(label)
        save()
    }


    // MARK: - Project CRUD

    func fetchProjects() throws -> [Project] {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { project in
                project.isDeleted == false
            },
            sortBy: [SortDescriptor(\.position)]
        )
        return try mainContext.fetch(descriptor)
    }

    func findProject(byGoogleTaskListId listId: String) throws -> Project? {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { project in
                project.googleTaskListId == listId && project.isDeleted == false
            }
        )
        return try mainContext.fetch(descriptor).first
    }

    func createProject(_ project: Project) {
        mainContext.insert(project)
        save()
    }

    func deleteProject(_ project: Project) {
        project.isDeleted = true
        save()
    }

    // MARK: - Event CRUD

    func fetchEvents(from startDate: Date, to endDate: Date, calendarIds: [String]? = nil) throws -> [CalendarEvent] {
        let allEvents: [CalendarEvent]

        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.isDeleted == false &&
                event.startDate >= startDate &&
                event.startDate <= endDate
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        allEvents = try mainContext.fetch(descriptor)

        if let calendarIds, !calendarIds.isEmpty {
            return allEvents.filter { calendarIds.contains($0.calendarId) }
        }
        return allEvents
    }

    func createEvent(_ event: CalendarEvent) {
        mainContext.insert(event)
        do {
            try mainContext.save()
        } catch {
            print("[DataController] createEvent failed: \(error)")
        }
    }

    // MARK: - Calendar CRUD

    func fetchCalendars() throws -> [UserCalendar] {
        let descriptor = FetchDescriptor<UserCalendar>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try mainContext.fetch(descriptor)
    }

    func fetchSelectedCalendarIds() throws -> [String] {
        let calendars = try fetchCalendars()
        return calendars.filter(\.isSelected).map(\.googleCalendarId)
    }

    func fetchMenuBarCalendarIds() throws -> [String] {
        let calendars = try fetchCalendars()
        return calendars.filter(\.showInMenuBar).map(\.googleCalendarId)
    }

    // MARK: - Sync Helpers

    func fetchTasksNeedingSync() throws -> [MadoTask] {
        let descriptor = FetchDescriptor<MadoTask>(
            predicate: #Predicate { task in
                task.needsSync == true
            }
        )
        return try mainContext.fetch(descriptor)
    }

    func fetchEventsNeedingSync() throws -> [CalendarEvent] {
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.needsSync == true
            }
        )
        return try mainContext.fetch(descriptor)
    }

    func findTask(byGoogleId googleId: String) throws -> MadoTask? {
        let descriptor = FetchDescriptor<MadoTask>(
            predicate: #Predicate { task in
                task.googleTaskId == googleId
            }
        )
        return try mainContext.fetch(descriptor).first
    }

    func findEvent(byGoogleId googleId: String) throws -> CalendarEvent? {
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.googleEventId == googleId
            }
        )
        return try mainContext.fetch(descriptor).first
    }



    func findTask(byGmailMessageId messageId: String) throws -> MadoTask? {
        let descriptor = FetchDescriptor<MadoTask>(
            predicate: #Predicate { task in
                task.gmailMessageId == messageId
            }
        )
        return try mainContext.fetch(descriptor).first
    }

    func findExistingTask(title: String, projectId: String) throws -> MadoTask? {
        let descriptor = FetchDescriptor<MadoTask>(
            predicate: #Predicate { task in
                task.isDeleted == false && task.isCompleted == false
            }
        )
        let tasks = try mainContext.fetch(descriptor)
        return tasks.first { $0.title == title && $0.projectId == projectId && $0.googleTaskId == nil }
    }

    func fetchTasksWithGmailLink() throws -> [MadoTask] {
        let descriptor = FetchDescriptor<MadoTask>(
            predicate: #Predicate { task in
                task.gmailMessageId != nil && task.isDeleted == false
            }
        )
        return try mainContext.fetch(descriptor)
    }

    /// Fetch ALL gmail-linked tasks including completed and deleted (for dedup checking)
    func fetchAllGmailLinkedTasks() throws -> [MadoTask] {
        let descriptor = FetchDescriptor<MadoTask>(
            predicate: #Predicate { task in
                task.gmailMessageId != nil
            }
        )
        return try mainContext.fetch(descriptor)
    }

    /// Remove duplicate gmail-linked tasks, keeping the oldest per thread/message
    func deduplicateGmailTasks() {
        guard let allGmail = try? fetchAllGmailLinkedTasks() else { return }

        // Group by threadId first (preferred), fall back to gmailMessageId
        var seen = Set<String>()
        // Sort by createdAt so we keep the oldest
        let sorted = allGmail.sorted { $0.createdAt < $1.createdAt }

        for task in sorted {
            let key = task.gmailThreadId ?? task.gmailMessageId ?? task.id
            if seen.contains(key) {
                // Duplicate — soft-delete it
                task.isDeleted = true
                task.needsSync = false
            } else {
                seen.insert(key)
            }
        }
        save()
    }

    func fetchPendingInvites() throws -> [CalendarEvent] {
        let now = Date()
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.isDeleted == false && event.endDate >= now && event.attendeesJSON != nil
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        let allEvents = try mainContext.fetch(descriptor)
        return allEvents.filter { event in
            event.attendees.contains { $0.isSelf && $0.responseStatus == "needsAction" }
        }
    }

    func findDeletedRecurringEventSeriesIds() throws -> Set<String> {
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.isDeleted == true && event.recurringEventId != nil
            }
        )
        let events = try mainContext.fetch(descriptor)
        return Set(events.compactMap(\.recurringEventId))
    }

    func fetchEventsBySeries(recurringEventId seriesId: String) throws -> [CalendarEvent] {
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.recurringEventId != nil && event.isDeleted == false
            }
        )
        let events = try mainContext.fetch(descriptor)
        return events.filter { $0.recurringEventId == seriesId }
    }

    func deleteEventSeries(recurringEventId seriesId: String) {
        do {
            let descriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { event in
                    event.recurringEventId != nil && event.isDeleted == false
                }
            )
            let events = try mainContext.fetch(descriptor)
            for event in events where event.recurringEventId == seriesId {
                event.isDeleted = true
                event.needsSync = true
                event.localUpdatedAt = Date()
            }

            let parentDescriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { event in
                    event.isDeleted == false && event.recurrenceRules != nil
                }
            )
            let parents = try mainContext.fetch(parentDescriptor)
            for parent in parents where parent.googleEventId == seriesId {
                parent.isDeleted = true
                parent.needsSync = true
                parent.localUpdatedAt = Date()
            }
            save()
        } catch {
            print("[DataController] deleteEventSeries failed: \(error)")
        }
    }

    func deleteEventsForCalendar(_ calendarId: String) {
        do {
            let descriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { event in
                    event.calendarId == calendarId
                }
            )
            let events = try mainContext.fetch(descriptor)
            for event in events {
                mainContext.delete(event)
            }
            try mainContext.save()
        } catch {
            print("[DataController] deleteEventsForCalendar failed: \(error)")
        }
    }

    func save() {
        do {
            try mainContext.save()
        } catch {
            print("[DataController] save failed: \(error)")
        }
    }
}

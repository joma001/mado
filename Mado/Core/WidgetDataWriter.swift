#if os(iOS)
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif
/// Writes today's events and tasks to App Group shared container for widget consumption.
@MainActor
final class WidgetDataWriter {
    static let shared = WidgetDataWriter()
    
    static let appGroupID = "group.io.mado.mobile"
    
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
    }
    
    private init() {}
    
    // MARK: - Write Data for Widget
    
    func writeWidgetData() {
        guard let containerURL = sharedContainerURL else {
            print("[WidgetData] No shared container available")
            return
        }
        
        let data = DataController.shared
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        
        do {
            // Build calendarId → colorHex map
            let calendars = try data.fetchCalendars()
            var colorMap: [String: String] = [:]
            for c in calendars {
                colorMap[c.googleCalendarId] = c.colorHex
            }
            
            // Fetch today's events
            let selectedIds = try data.fetchSelectedCalendarIds()
            let allEvents = try data.fetchEvents(from: startOfDay, to: endOfDay, calendarIds: selectedIds)
            let events = allEvents
                .filter { $0.sourceTaskId == nil }
                .sorted { $0.startDate < $1.startDate }
                .map { event in
                    WidgetEvent(
                        id: event.googleEventId,
                        title: event.title,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        isAllDay: event.isAllDay,
                        colorHex: colorMap[event.calendarId] ?? "4285F4",
                        hasConference: event.conferenceURL != nil && !(event.conferenceURL?.isEmpty ?? true)
                    )
                }
            
            // Fetch today's incomplete tasks
            let allTasks = try data.fetchTasks(includeCompleted: false)
            let tasks = allTasks
                .filter { !$0.isCompleted }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                .prefix(10)
                .map { task in
                    WidgetTask(
                        id: task.id,
                        title: task.title,
                        dueDate: task.dueDate,
                        isCompleted: task.isCompleted
                    )
                }
            
            let widgetData = WidgetSharedData(
                events: events,
                tasks: Array(tasks),
                lastUpdated: Date()
            )
            
            let encoded = try JSONEncoder().encode(widgetData)
            let fileURL = containerURL.appendingPathComponent("widget_data.json")
            try encoded.write(to: fileURL, options: .atomic)
            
            // Tell WidgetKit to reload
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            
        } catch {
            print("[WidgetData] Failed to write widget data: \(error)")
        }
    }
}
#endif

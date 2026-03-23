import Foundation
import SwiftUI


@MainActor
@Observable
final class MenuBarViewModel {
    static let shared = MenuBarViewModel()

    // MARK: - Grouped Data
    var pastEvents: [CalendarEvent] = []
    var ongoingEvents: [CalendarEvent] = []
    var upcomingItems: [MenuBarItem] = []
    var overdueTasks: [MadoTask] = []

    // MARK: - State
    var quickAddText = ""
    var nextMeetingURL: URL?

    private let data = DataController.shared
    private var refreshTimer: Timer?

    // MARK: - Google Calendar Color ID → Hex Mapping
    private static let googleColorIdMap: [String: String] = [
        "1": "7986CB",  // Lavender
        "2": "33B679",  // Sage
        "3": "8E24AA",  // Grape
        "4": "E67C73",  // Flamingo
        "5": "F6BF26",  // Banana
        "6": "F4511E",  // Tangerine
        "7": "039BE5",  // Peacock
        "8": "616161",  // Graphite
        "9": "3F51B5",  // Blueberry
        "10": "0B8043", // Basil
        "11": "D50000",  // Tomato
    ]

    private init() {}

    // MARK: - Lifecycle

    func load() {
        refreshData()
        startAutoRefresh()
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Data Loading

    func refreshData() {
        loadPastEvents()
        loadOngoingEvents()
        loadUpcomingItems()
        loadOverdueTasks()
        findNextMeetingURL()
    }

    // MARK: - Actions

    func quickAddTask() {
        let trimmed = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = MadoTask(title: trimmed, dueDate: Date())
        data.createTask(task)
        quickAddText = ""
        refreshData()
    }

    func toggleTask(_ task: MadoTask) {
        if task.isCompleted {
            task.markIncomplete()
        } else {
            task.markCompleted()
        }
        data.save()
        refreshData()
    }

    // MARK: - Computed Helpers

    func timeRemainingText(for event: CalendarEvent) -> String {
        let remaining = Int(event.endDate.timeIntervalSince(Date()) / 60)
        if remaining <= 0 { return "ending" }
        if remaining >= 60 {
            let hours = remaining / 60
            let mins = remaining % 60
            return mins > 0 ? "\(hours)h \(mins)m left" : "\(hours)h left"
        }
        return "\(remaining)m left"
    }

    func upcomingTimeText(for event: CalendarEvent) -> String {
        if event.isAllDay { return "All day" }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeStr = formatter.string(from: event.startDate)
        // Drop leading zero and lowercase am/pm: "1:30 pm"
        return timeStr
            .replacingOccurrences(of: " AM", with: " am")
            .replacingOccurrences(of: " PM", with: " pm")
    }

    func overdueDateText(for task: MadoTask) -> String? {
        guard let dueDate = task.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: dueDate)
    }

    func eventColor(for event: CalendarEvent) -> Color {
        // First try event-level colorId (Google Calendar API color IDs)
        if let colorId = event.colorId,
           let hex = Self.googleColorIdMap[colorId] {
            return Color(hex: hex)
        }

        // Fall back to the parent calendar's color
        if let calendar = try? data.fetchCalendars().first(where: { $0.googleCalendarId == event.calendarId }) {
            return calendar.displayColor
        }

        return MadoColors.calendarDefault
    }

    func hasVideoLink(for event: CalendarEvent) -> Bool {
        extractMeetURL(from: event) != nil
    }

    func meetingURL(for event: CalendarEvent) -> URL? {
        extractMeetURL(from: event)
    }

    func locationURL(for event: CalendarEvent) -> URL? {
        guard let location = event.location, !location.isEmpty else { return nil }
        if let url = URL(string: location), let scheme = url.scheme, scheme.hasPrefix("http") {
            return url
        }
        let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    func hasAttendees(for event: CalendarEvent) -> Bool {
        !event.attendees.isEmpty
    }

    func joinNextMeeting() {
        // Refresh data first to ensure we have the latest meeting URL
        if nextMeetingURL == nil { refreshData() }
        guard let url = nextMeetingURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        // Refresh every 30 seconds to keep time badges current
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshData()
            }
        }
    }

    private func menuBarCalendarIds() -> [String]? {
        let ids = (try? data.fetchMenuBarCalendarIds()) ?? []
        return ids.isEmpty ? nil : ids
    }

    private func loadPastEvents() {
        do {
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

            let todayEvents = try data.fetchEvents(from: startOfDay, to: endOfDay, calendarIds: menuBarCalendarIds())
            pastEvents = todayEvents.filter { event in
                !event.isAllDay && event.endDate <= now
            }.sorted { $0.startDate < $1.startDate }
        } catch {
            pastEvents = []
        }
    }

    private func loadOngoingEvents() {
        do {
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

            let todayEvents = try data.fetchEvents(from: startOfDay, to: endOfDay, calendarIds: menuBarCalendarIds())
            ongoingEvents = todayEvents.filter { event in
                !event.isAllDay &&
                event.startDate <= now &&
                event.endDate > now
            }
        } catch {
            ongoingEvents = []
        }
    }

    private func loadUpcomingItems() {
        do {
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

            let todayEvents = try data.fetchEvents(from: startOfDay, to: endOfDay, calendarIds: menuBarCalendarIds())
            let futureEvents = todayEvents.filter { event in
                event.startDate > now || event.isAllDay
            }

            // Today's incomplete tasks (not overdue — due today or no due date)
            let calendar = Calendar.current
            let allTasks = try data.fetchTasks()
            let todayTasks = allTasks.filter { task in
                !task.isCompleted &&
                !task.isDeleted &&
                task.parentTaskId == nil && (
                    task.dueDate == nil ||
                    calendar.isDateInToday(task.dueDate!)
                )
            }

            var items: [MenuBarItem] = []
            items.append(contentsOf: futureEvents.map { .event($0) })
            items.append(contentsOf: todayTasks.map { .task($0) })

            // Sort: events by start time, then tasks
            upcomingItems = items.sorted { a, b in
                switch (a, b) {
                case (.event, .task): return true   // events before tasks
                case (.task, .event): return false
                default: return a.sortDate < b.sortDate
                }
            }
            .prefix(10)
            .map { $0 }
        } catch {
            upcomingItems = []
        }
    }

    private func loadOverdueTasks() {
        do {
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())

            let allTasks = try data.fetchTasks()
            overdueTasks = allTasks.filter { task in
                !task.isCompleted &&
                !task.isDeleted &&
                task.parentTaskId == nil &&
                task.dueDate != nil &&
                task.dueDate! < startOfToday
            }
            .sorted { ($0.dueDate ?? .distantPast) > ($1.dueDate ?? .distantPast) }
            .prefix(10)
            .map { $0 }
        } catch {
            overdueTasks = []
        }
    }

    private func findNextMeetingURL() {
        // Find the next event with a video link (ongoing or upcoming)
        let allEvents = ongoingEvents + upcomingItems.compactMap { item -> CalendarEvent? in
            if case .event(let e) = item { return e }
            return nil
        }

        for event in allEvents {
            if let url = extractMeetURL(from: event) {
                nextMeetingURL = url
                return
            }
        }
        nextMeetingURL = nil
    }

    private func extractMeetURL(from event: CalendarEvent) -> URL? {
        if let conferenceURL = event.conferenceURL, let url = URL(string: conferenceURL) {
            return url
        }
        let fields = [event.location, event.notes].compactMap { $0 }
        for field in fields {
            if let range = field.range(of: "https://meet\\.google\\.com/[a-z\\-]+", options: .regularExpression) {
                return URL(string: String(field[range]))
            }
            if let range = field.range(of: "https://[a-z0-9]+\\.zoom\\.us/j/[0-9]+", options: .regularExpression) {
                return URL(string: String(field[range]))
            }
            if let range = field.range(of: "https://teams\\.microsoft\\.com/[^\\s]+", options: .regularExpression) {
                return URL(string: String(field[range]))
            }
        }
        return nil
    }
}

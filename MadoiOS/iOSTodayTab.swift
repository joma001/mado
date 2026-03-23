import SwiftUI

struct iOSTodayTab: View {
    @State private var viewModel = iOSTodayViewModel()

    private var todayFormatted: String {
        DateFormatters.fullWeekdayDate.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.ongoingEvents.isEmpty &&
                       viewModel.upcomingItems.isEmpty &&
                       viewModel.pastEvents.isEmpty &&
                       viewModel.overdueTasks.isEmpty {
                        emptyState
                    } else {
                        contentSections
                    }
                }
                .padding(.bottom, 100) // Space for FAB
            }
            .navigationTitle("Today")
            .refreshable {
                await SyncEngine.shared.syncAll()
                viewModel.refreshData()
            }
            .onAppear { viewModel.load() }
        }
    }

    // MARK: - Content

    private var contentSections: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ongoing
            if !viewModel.ongoingEvents.isEmpty {
                sectionHeader("Ongoing")
                ForEach(viewModel.ongoingEvents, id: \.id) { event in
                    iOSOngoingEventCard(event: event, viewModel: viewModel)
                }
            }

            // Upcoming
            if !viewModel.upcomingItems.isEmpty {
                sectionHeader("Upcoming")
                ForEach(viewModel.upcomingItems) { item in
                    switch item {
                    case .event(let event):
                        iOSUpcomingEventRow(event: event, viewModel: viewModel)
                    case .task(let task):
                        iOSTaskRow(task: task) {
                            viewModel.toggleTask(task)
                        }
                    }
                }
            }

            // Earlier (past events)
            if !viewModel.pastEvents.isEmpty {
                sectionHeader("Earlier")
                ForEach(viewModel.pastEvents, id: \.id) { event in
                    iOSPastEventRow(event: event, viewModel: viewModel)
                }
            }

            // Overdue
            if !viewModel.overdueTasks.isEmpty {
                sectionHeader("Overdue")
                ForEach(viewModel.overdueTasks, id: \.id) { task in
                    iOSOverdueTaskRow(task: task, viewModel: viewModel) {
                        viewModel.toggleTask(task)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(MadoColors.textTertiary)
            Text("All clear for today")
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(MadoTheme.Font.caption)
            .foregroundColor(MadoColors.textTertiary)
            .textCase(.uppercase)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }
}

// MARK: - Ongoing Event Card

private struct iOSOngoingEventCard: View {
    let event: CalendarEvent
    let viewModel: iOSTodayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.title)
                    .font(MadoTheme.Font.bodyMedium)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if !event.attendees.isEmpty {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }

                if event.hasConference {
                    Button {
                        if let url = event.conferenceURL.flatMap({ URL(string: $0) }) {
                            openURL(url)
                        }
                    } label: {
                        Image(systemName: "video.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                Text(viewModel.timeRemainingText(for: event))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            if let location = event.location, !location.isEmpty {
                Text(location)
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(viewModel.eventColor(for: event))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }

    @Environment(\.openURL) private var openURL
}

// MARK: - Upcoming Event Row

private struct iOSUpcomingEventRow: View {
    let event: CalendarEvent
    let viewModel: iOSTodayViewModel

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(viewModel.eventColor(for: event))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textPrimary)
                    .lineLimit(1)

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(MadoTheme.Font.tiny)
                        .foregroundColor(MadoColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if !event.attendees.isEmpty {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 10))
                    .foregroundColor(MadoColors.textTertiary)
            }

            if event.hasConference {
                Image(systemName: "video.fill")
                    .font(.system(size: 10))
                    .foregroundColor(MadoColors.textTertiary)
            }

            Text(viewModel.upcomingTimeText(for: event))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(viewModel.eventColor(for: event))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(viewModel.eventColor(for: event).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - Past Event Row

private struct iOSPastEventRow: View {
    let event: CalendarEvent
    let viewModel: iOSTodayViewModel

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(viewModel.eventColor(for: event).opacity(0.35))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textTertiary)
                    .lineLimit(1)

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(MadoTheme.Font.tiny)
                        .foregroundColor(MadoColors.textTertiary.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Text(viewModel.pastTimeText(for: event))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(MadoColors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(MadoColors.textTertiary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .opacity(0.7)
    }
}

// MARK: - Task Row

private struct iOSTaskRow: View {
    let task: MadoTask
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(task.isCompleted ? MadoColors.checkboxChecked : MadoColors.checkboxUnchecked)
            }

            Text(task.title)
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textPrimary)
                .lineLimit(1)
                .strikethrough(task.isCompleted)

            Spacer()

            iOSPriorityBadge(priority: task.priority)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - Overdue Task Row

private struct iOSOverdueTaskRow: View {
    let task: MadoTask
    let viewModel: iOSTodayViewModel
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundColor(MadoColors.error.opacity(0.5))
            }

            Text(task.title)
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("T")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(MadoColors.accent)
                .frame(width: 18, height: 18)
                .background(MadoColors.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            if let dateText = viewModel.overdueDateText(for: task) {
                Text(dateText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(MadoColors.error)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(MadoColors.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(MadoColors.error.opacity(0.04))
    }
}

// MARK: - Shared Helpers

private struct iOSPriorityBadge: View {
    let priority: TaskPriority

    private var label: String? {
        switch priority {
        case .high: return "1"
        case .medium: return "2"
        case .low: return "3"
        case .none: return nil
        }
    }

    private var color: Color {
        switch priority {
        case .high: return MadoColors.priorityHigh
        case .medium: return MadoColors.priorityMedium
        case .low: return MadoColors.priorityLow
        case .none: return .clear
        }
    }

    var body: some View {
        if let label {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .frame(width: 18, height: 18)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}

// MARK: - iOS Today ViewModel (wraps shared data layer)

@MainActor
@Observable
final class iOSTodayViewModel {
    var ongoingEvents: [CalendarEvent] = []
    var upcomingItems: [MenuBarItem] = []
    var pastEvents: [CalendarEvent] = []
    var overdueTasks: [MadoTask] = []

    private let data = DataController.shared
    private var refreshTimer: Timer?

    private static let googleColorIdMap: [String: String] = [
        "1": "7986CB", "2": "33B679", "3": "8E24AA", "4": "E67C73",
        "5": "F6BF26", "6": "F4511E", "7": "039BE5", "8": "616161",
        "9": "3F51B5", "10": "0B8043", "11": "D50000",
    ]

    func load() {
        refreshData()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshData() }
        }
    }

    func refreshData() {
        loadOngoingEvents()
        loadUpcomingItems()
        loadPastEvents()
        loadOverdueTasks()
    }

    func toggleTask(_ task: MadoTask) {
        if task.isCompleted { task.markIncomplete() } else { task.markCompleted() }
        data.save()
        SyncEngine.shared.schedulePush()
        refreshData()
    }

    func timeRemainingText(for event: CalendarEvent) -> String {
        let remaining = Int(event.endDate.timeIntervalSince(Date()) / 60)
        if remaining <= 0 { return "ending" }
        if remaining >= 60 {
            let h = remaining / 60, m = remaining % 60
            return m > 0 ? "\(h)h \(m)m left" : "\(h)h left"
        }
        return "\(remaining)m left"
    }

    func upcomingTimeText(for event: CalendarEvent) -> String {
        if event.isAllDay { return "All day" }
        return DateFormatters.time12h.string(from: event.startDate)
            .replacingOccurrences(of: " AM", with: " am")
            .replacingOccurrences(of: " PM", with: " pm")
    }

    func pastTimeText(for event: CalendarEvent) -> String {
        let formatter = DateFormatters.time12h
        let start = formatter.string(from: event.startDate)
            .replacingOccurrences(of: " AM", with: "a")
            .replacingOccurrences(of: " PM", with: "p")
        let end = formatter.string(from: event.endDate)
            .replacingOccurrences(of: " AM", with: "a")
            .replacingOccurrences(of: " PM", with: "p")
        return "\(start)–\(end)"
    }

    func overdueDateText(for task: MadoTask) -> String? {
        guard let d = task.dueDate else { return nil }
        return DateFormatters.shortMonthDay.string(from: d)
    }

    func eventColor(for event: CalendarEvent) -> Color {
        if let cid = event.colorId, let hex = Self.googleColorIdMap[cid] {
            return Color(hex: hex)
        }
        if let cal = try? data.fetchCalendars().first(where: { $0.googleCalendarId == event.calendarId }) {
            return cal.displayColor
        }
        return MadoColors.calendarDefault
    }

    // MARK: - Private

    private func selectedCalendarIds() -> [String]? {
        let ids = (try? data.fetchSelectedCalendarIds()) ?? []
        return ids.isEmpty ? nil : ids
    }

    private func loadOngoingEvents() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        guard let events = try? data.fetchEvents(from: startOfDay, to: endOfDay, calendarIds: selectedCalendarIds()) else {
            ongoingEvents = []; return
        }
        ongoingEvents = events.filter { !$0.isAllDay && $0.startDate <= now && $0.endDate > now }
    }

    private func loadUpcomingItems() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        guard let todayEvents = try? data.fetchEvents(from: startOfDay, to: endOfDay, calendarIds: selectedCalendarIds()),
              let allTasks = try? data.fetchTasks() else {
            upcomingItems = []; return
        }
        let futureEvents = todayEvents.filter { $0.startDate > now || $0.isAllDay }
        let cal = Calendar.current
        let todayTasks = allTasks.filter {
            !$0.isCompleted && !$0.isDeleted && $0.parentTaskId == nil &&
            ($0.dueDate == nil || cal.isDateInToday($0.dueDate!))
        }
        var items: [MenuBarItem] = []
        items.append(contentsOf: futureEvents.map { .event($0) })
        items.append(contentsOf: todayTasks.map { .task($0) })
        upcomingItems = items.sorted { a, b in
            switch (a, b) {
            case (.event, .task): return true
            case (.task, .event): return false
            default: return a.sortDate < b.sortDate
            }
        }.prefix(15).map { $0 }
    }

    private func loadPastEvents() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        guard let todayEvents = try? data.fetchEvents(from: startOfDay, to: endOfDay, calendarIds: selectedCalendarIds()) else {
            pastEvents = []; return
        }
        pastEvents = todayEvents
            .filter { !$0.isAllDay && $0.endDate <= now }
            .sorted { $0.startDate > $1.startDate }
    }

    private func loadOverdueTasks() {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard let allTasks = try? data.fetchTasks() else { overdueTasks = []; return }
        overdueTasks = allTasks.filter {
            !$0.isCompleted && !$0.isDeleted && $0.parentTaskId == nil &&
            $0.dueDate != nil && $0.dueDate! < startOfToday
        }.sorted { ($0.dueDate ?? .distantPast) > ($1.dueDate ?? .distantPast) }
        .prefix(15).map { $0 }
    }
}

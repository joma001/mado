import SwiftUI

struct iOSCalendarTab: View {
    @Bindable var viewModel = CalendarViewModel()
    @State private var selectedEvent: CalendarEvent?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View mode picker
                Picker("View", selection: $viewModel.viewMode) {
                    Text("Month").tag(CalendarViewMode.monthly)
                    Text("Week").tag(CalendarViewMode.weekly)
                    Text("Day").tag(CalendarViewMode.daily)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                // Calendar content
                ScrollView {
                    switch viewModel.viewMode {
                    case .monthly:
                        iOSMonthlyView(viewModel: viewModel, selectedEvent: $selectedEvent)
                    case .weekly:
                        iOSWeeklyView(viewModel: viewModel, selectedEvent: $selectedEvent)
                    case .daily:
                        iOSDailyView(viewModel: viewModel, selectedEvent: $selectedEvent)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.goToToday()
                    } label: {
                        Text("Today")
                            .font(MadoTheme.Font.caption)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button { viewModel.navigateBack() } label: {
                            Image(systemName: "chevron.left")
                        }
                        Button { viewModel.navigateForward() } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
            }
            .sheet(item: $selectedEvent) { event in
                iOSEventDetailView(event: event, viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .onAppear { viewModel.loadEvents() }
            .onChange(of: viewModel.selectedDate) { _, _ in viewModel.loadEvents() }
            .onChange(of: viewModel.viewMode) { _, _ in viewModel.loadEvents() }
        }
    }

    private var navigationTitle: String {
        DateFormatters.monthYear.string(from: viewModel.selectedDate)
    }
}

// MARK: - Monthly View

private struct iOSMonthlyView: View {
    let viewModel: CalendarViewModel
    @Binding var selectedEvent: CalendarEvent?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 0) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(MadoTheme.Font.tiny)
                        .foregroundColor(MadoColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)

            // Date grid
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(viewModel.currentMonthGrid, id: \.self) { week in
                    ForEach(week, id: \.self) { date in
                        iOSMonthDayCell(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate),
                            isToday: Calendar.current.isDateInToday(date),
                            events: viewModel.events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
                        )
                        .onTapGesture {
                            viewModel.selectedDate = date
                            viewModel.viewMode = .daily
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct iOSMonthDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let events: [CalendarEvent]

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? .white : MadoColors.textPrimary)
                .frame(width: 28, height: 28)
                .background(isToday ? MadoColors.accent : Color.clear)
                .clipShape(Circle())

            HStack(spacing: 2) {
                ForEach(events.prefix(3), id: \.id) { event in
                    if event.isPendingInvite {
                        Circle()
                            .stroke(MadoColors.accent, lineWidth: 1)
                            .frame(width: 4, height: 4)
                    } else if event.isDeclined {
                        Circle()
                            .fill(MadoColors.accent.opacity(0.3))
                            .frame(width: 4, height: 4)
                    } else {
                        Circle()
                            .fill(MadoColors.accent)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(isSelected ? MadoColors.accent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Weekly View

private struct iOSWeeklyView: View {
    let viewModel: CalendarViewModel
    @Binding var selectedEvent: CalendarEvent?

    /// Rolling 7 days starting from selectedDate (today by default)
    private var weekDates: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: viewModel.selectedDate)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                let dayEvents = viewModel.events.filter {
                    Calendar.current.isDate($0.startDate, inSameDayAs: date)
                }

                VStack(alignment: .leading, spacing: 0) {
                    // Day header
                    HStack {
                        Text(dayHeaderText(date))
                            .font(MadoTheme.Font.captionMedium)
                            .foregroundColor(Calendar.current.isDateInToday(date)
                                ? MadoColors.accent
                                : MadoColors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                    if dayEvents.isEmpty {
                        Text("No events")
                            .font(MadoTheme.Font.tiny)
                            .foregroundColor(MadoColors.textTertiary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    } else {
                        ForEach(dayEvents, id: \.id) { event in
                            iOSEventListRow(event: event, color: viewModel.calendarColorMap[event.calendarId] ?? MadoColors.calendarDefault)
                                .onTapGesture { selectedEvent = event }
                        }
                    }

                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func dayHeaderText(_ date: Date) -> String {
        let text = DateFormatters.shortDayDate.string(from: date)
        return Calendar.current.isDateInToday(date) ? "\(text) — Today" : text
    }
}

// MARK: - Daily View

private struct iOSDailyView: View {
    let viewModel: CalendarViewModel
    @Binding var selectedEvent: CalendarEvent?

    private var dayEvents: [CalendarEvent] {
        viewModel.events
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: viewModel.selectedDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if dayEvents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(MadoColors.textTertiary)
                    Text("No events")
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(dayEvents, id: \.id) { event in
                    iOSEventListRow(event: event, color: viewModel.calendarColorMap[event.calendarId] ?? MadoColors.calendarDefault)
                        .onTapGesture { selectedEvent = event }
                }
            }
        }
    }
}

// MARK: - Event List Row (shared)

private struct iOSEventListRow: View {
    let event: CalendarEvent
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Left accent bar: dashed for pending, faint for declined, solid for confirmed
            if event.isPendingInvite {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: 4)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(event.isDeclined ? 0.3 : 1.0))
                    .frame(width: 4)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(event.isDeclined ? MadoColors.textTertiary : MadoColors.textPrimary)
                    .strikethrough(event.isDeclined, color: MadoColors.textTertiary)
                    .lineLimit(1)

                Text(timeRange)
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(event.isDeclined ? MadoColors.textPlaceholder : MadoColors.textSecondary)
            }

            Spacer()

            if event.hasConference {
                Image(systemName: "video.fill")
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }

            if !event.attendees.isEmpty {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(MadoColors.textTertiary)
            }
        }
        .frame(height: 50)
        .padding(.horizontal, 20)
        .padding(.vertical, 2)
        .opacity(event.isDeclined ? 0.55 : 1.0)
    }

    private var timeRange: String {
        if event.isAllDay { return "All day" }
        return "\(DateFormatters.time12h.string(from: event.startDate)) – \(DateFormatters.time12h.string(from: event.endDate))"
    }
}

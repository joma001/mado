import SwiftUI

struct iOSQuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var mode: QuickAddMode = .task
    @FocusState private var isFocused: Bool

    private let data = DataController.shared
    private let sync = SyncEngine.shared

    enum QuickAddMode: String, CaseIterable {
        case task = "Task"
        case event = "Event"
    }

    /// Parsed result for events (recomputed on title change)
    private var parsedEvent: ParsedEvent {
        NaturalLanguageParser.parse(title.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Parsed result for tasks
    private var parsedTask: NaturalDateParser.Result {
        NaturalDateParser.parse(title.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Mode picker
                Picker("Type", selection: $mode) {
                    ForEach(QuickAddMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                // Input
                TextField(
                    mode == .task
                        ? "New task... (e.g. 내일 3시 미팅)"
                        : "New event... (e.g. Lunch tomorrow 1pm)",
                    text: $title
                )
                .font(MadoTheme.Font.title2)
                .focused($isFocused)
                .onSubmit { addItem() }

                // Parsed preview
                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    parsedPreview
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { addItem() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }

    // MARK: - Parsed Preview

    @ViewBuilder
    private var parsedPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if mode == .event {
                let parsed = parsedEvent
                HStack(spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 12))
                        .foregroundColor(MadoColors.textTertiary)
                    Text(parsed.title.isEmpty ? "New Event" : parsed.title)
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textPrimary)
                }
                if let start = parsed.startDate {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(MadoColors.accent)
                        if parsed.isAllDay {
                            Text(formatDateOnly(start))
                                .font(MadoTheme.Font.caption)
                                .foregroundColor(MadoColors.accent)
                            Text("All day")
                                .font(MadoTheme.Font.caption)
                                .foregroundColor(MadoColors.textTertiary)
                        } else if let end = parsed.endDate {
                            Text("\(formatDateTime(start)) – \(formatTime(end))")
                                .font(MadoTheme.Font.caption)
                                .foregroundColor(MadoColors.accent)
                        } else {
                            Text(formatDateTime(start))
                                .font(MadoTheme.Font.caption)
                                .foregroundColor(MadoColors.accent)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(MadoColors.textTertiary)
                        Text("No date/time detected")
                            .font(MadoTheme.Font.caption)
                            .foregroundColor(MadoColors.textTertiary)
                    }
                }
            } else {
                let parsed = parsedTask
                HStack(spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 12))
                        .foregroundColor(MadoColors.textTertiary)
                    Text(parsed.title)
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textPrimary)
                }
                if let date = parsed.dueDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(MadoColors.accent)
                        Text(formatDateTime(date))
                            .font(MadoTheme.Font.caption)
                            .foregroundColor(MadoColors.accent)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.md)
                .fill(MadoColors.surfaceSecondary)
        )
    }

    // MARK: - Actions

    private func addItem() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch mode {
        case .task:
            let parsed = parsedTask
            let task = MadoTask(title: parsed.title, dueDate: parsed.dueDate ?? Date())
            data.createTask(task)
            sync.schedulePush()
        case .event:
            let parsed = parsedEvent
            let cal = Calendar.current
            let startDate = parsed.startDate ?? cal.date(byAdding: .hour, value: 1, to: Date())!
            let endDate = parsed.endDate ?? cal.date(byAdding: .minute, value: AppSettings.shared.defaultEventDuration, to: startDate)!
            let calendarId = sync.primaryCalendarId()
            let calAccountEmail = (try? DataController.shared.fetchCalendars().first(where: { $0.googleCalendarId == calendarId })?.accountEmail)
                ?? AuthenticationManager.shared.primaryAccount?.email ?? ""
            let event = CalendarEvent(
                googleEventId: "",
                calendarId: calendarId,
                title: parsed.title.isEmpty ? trimmed : parsed.title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: parsed.isAllDay,
                accountEmail: calAccountEmail
            )
            event.needsSync = true
            data.createEvent(event)
            sync.schedulePush()
        }

        dismiss()
    }

    // MARK: - Formatting Helpers

    private func formatDateTime(_ date: Date) -> String {
        let cal = Calendar.current
        let time = DateFormatters.time12h.string(from: date)
        if cal.isDateInToday(date) {
            return "Today \(time)"
        } else if cal.isDateInTomorrow(date) {
            return "Tomorrow \(time)"
        } else {
            return DateFormatters.dayDateTime.string(from: date)
        }
    }

    private func formatTime(_ date: Date) -> String {
        DateFormatters.time12h.string(from: date)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today"
        } else if cal.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return DateFormatters.shortDayDate.string(from: date)
        }
    }
}

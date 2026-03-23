import SwiftUI

struct EventCreatePopover: View {
    @Bindable var viewModel: CalendarViewModel
    var todoVM: TodoViewModel

    enum CreationMode: String, CaseIterable {
        case task = "Task"
        case event = "Event"
    }

    @State private var mode: CreationMode = .event
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var location = ""
    @State private var notes = ""
    @State private var isAllDay = false
    @State private var guestEmails: [String] = []
    @State private var guestInput = ""
    @State private var addMeetLink = false
    @FocusState private var titleFocused: Bool
    @FocusState private var guestFieldFocused: Bool

    private let auth = AuthenticationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mode tabs + All day toggle
            modeTabBar

            Divider().foregroundColor(MadoColors.divider)

            // Date/time row
            dateTimeRow

            Divider().foregroundColor(MadoColors.divider)

            // Title row
            titleRow

            Divider().foregroundColor(MadoColors.divider)

            if mode == .event {
                // Fields
                eventFields

                Divider().foregroundColor(MadoColors.divider)

                // Footer with account + save
                footer
            } else {
                // Task mode — minimal
                Spacer(minLength: 0)
                taskFooter
            }
        }
        .frame(minWidth: 340, maxWidth: 340, minHeight: 300)
        .background(MadoColors.surface)
        .animation(nil, value: mode)
        .onAppear {
            if let start = viewModel.newEventStartDate {
                startDate = start
                endDate = viewModel.newEventEndDate ?? Calendar.current.date(
                    byAdding: .minute,
                    value: AppSettings.shared.defaultEventDuration,
                    to: start
                ) ?? start
            }
            titleFocused = true
        }
    }

    // MARK: - Mode Tab Bar

    private var modeTabBar: some View {
        HStack {
            HStack(spacing: 2) {
                ForEach(CreationMode.allCases, id: \.self) { m in
                    Button {
                        var t = Transaction(); t.disablesAnimations = true; withTransaction(t) { mode = m }
                    } label: {
                        HStack(spacing: MadoTheme.Spacing.xxs) {
                            Image(systemName: m == .task ? "checkmark.circle" : "calendar")
                                .font(.system(size: 10))
                            Text(m.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, MadoTheme.Spacing.sm)
                        .padding(.vertical, MadoTheme.Spacing.xxs + 1)
                        .foregroundColor(mode == m ? .white : MadoColors.textSecondary)
                        .background(
                            RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                                .fill(mode == m ? MadoColors.accent : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(MadoColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.md))

            Spacer()

            if mode == .event {
                Toggle(isOn: $isAllDay) {
                    Text("All day")
                        .font(.system(size: 11))
                        .foregroundColor(MadoColors.textSecondary)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
    }

    // MARK: - Date/Time Row

    private var dateTimeRow: some View {
        HStack(spacing: MadoTheme.Spacing.xs) {
            if isAllDay {
                compactDatePill(date: startDate)
            } else {
                compactDatePill(date: startDate)
                compactTimePill(date: $startDate)
                compactTimePill(date: $endDate)
                compactDatePill(date: endDate)
            }
            Spacer()
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
        .background(MadoColors.surfaceSecondary.opacity(0.4))
    }

    private func compactDatePill(date: Date) -> some View {
        Text(shortDate(date))
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(MadoColors.textPrimary)
            .padding(.horizontal, MadoTheme.Spacing.sm)
            .padding(.vertical, MadoTheme.Spacing.xxs)
            .background(MadoColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .stroke(MadoColors.border, lineWidth: 0.5)
            )
    }

    private func compactTimePill(date: Binding<Date>) -> some View {
        DatePicker("", selection: date, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .font(.system(size: 11, weight: .medium))
            .scaleEffect(0.85)
            .frame(height: 24)
    }

    // MARK: - Title Row

    private var titleRow: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            Circle()
                .fill(MadoColors.accent)
                .frame(width: 10, height: 10)

            Image(systemName: "chevron.down")
                .font(.system(size: 8))
                .foregroundColor(MadoColors.textTertiary)

            TextField(mode == .event ? "Event Title" : "Task Title", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(MadoColors.textPrimary)
                .focused($titleFocused)
                .onSubmit { save() }

            if mode == .event {
                Button { addMeetLink.toggle() } label: {
                    Image(systemName: addMeetLink ? "video.fill" : "video")
                        .font(.system(size: 12))
                        .foregroundColor(addMeetLink ? Color(hex: "00897B") : MadoColors.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                                .fill(addMeetLink ? Color(hex: "00897B").opacity(0.1) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Add Google Meet link")
            }
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.md)
    }

    // MARK: - Event Fields

    private var eventFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Add guests
            fieldRow(icon: "person.badge.plus", iconSize: 12) {
                if guestEmails.isEmpty {
                    TextField("Add guests", text: $guestInput)
                        .textFieldStyle(.plain)
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textPrimary)
                        .focused($guestFieldFocused)
                        .onSubmit { addGuest() }
                } else {
                    VStack(alignment: .leading, spacing: MadoTheme.Spacing.xs) {
                        FlowLayout(spacing: 4) {
                            ForEach(guestEmails, id: \.self) { email in
                                guestChip(email)
                            }
                        }
                        TextField("Add another guest", text: $guestInput)
                            .textFieldStyle(.plain)
                            .font(MadoTheme.Font.caption)
                            .focused($guestFieldFocused)
                            .onSubmit { addGuest() }
                    }
                }
            }

            Divider().foregroundColor(MadoColors.divider).padding(.leading, 34)

            // Location
            fieldRow(icon: "mappin.and.ellipse", iconSize: 12) {
                TextField("Location", text: $location)
                    .textFieldStyle(.plain)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textPrimary)
            }

            Divider().foregroundColor(MadoColors.divider).padding(.leading, 34)

            // Description
            fieldRow(icon: "text.alignleft", iconSize: 12) {
                TextField("Description", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textPrimary)
                    .lineLimit(1...4)
            }
        }
    }

    private func fieldRow<Content: View>(icon: String, iconSize: CGFloat = 11, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: MadoTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundColor(MadoColors.textTertiary)
                .frame(width: 16)
                .padding(.top, 2)
            content()
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm + 2)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            // Account badge
            if let email = auth.status.userEmail {
                HStack(spacing: MadoTheme.Spacing.xxs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                        .foregroundColor(MadoColors.accent)
                    Text(email)
                        .font(.system(size: 10))
                        .foregroundColor(MadoColors.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, MadoTheme.Spacing.xs)
                .padding(.vertical, MadoTheme.Spacing.xxxs)
                .background(MadoColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.xs))
            }

            Spacer()

            Button("Cancel") {
                viewModel.cancelEventCreation()
            }
            .font(MadoTheme.Font.captionMedium)
            .foregroundColor(MadoColors.textSecondary)
            .buttonStyle(.plain)

            Button("Save") { save() }
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(.white)
                .padding(.horizontal, MadoTheme.Spacing.md)
                .padding(.vertical, MadoTheme.Spacing.xxs + 1)
                .background(MadoColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
    }

    private var taskFooter: some View {
        HStack {
            Spacer()
            Button("Cancel") {
                viewModel.cancelEventCreation()
            }
            .font(MadoTheme.Font.captionMedium)
            .foregroundColor(MadoColors.textSecondary)
            .buttonStyle(.plain)

            Button("Add Task") { saveAsTask() }
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(.white)
                .padding(.horizontal, MadoTheme.Spacing.md)
                .padding(.vertical, MadoTheme.Spacing.xxs + 1)
                .background(MadoColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
    }

    // MARK: - Guest Chip

    private func guestChip(_ email: String) -> some View {
        HStack(spacing: 4) {
            Text(email)
                .font(MadoTheme.Font.caption)
                .foregroundColor(MadoColors.textPrimary)
                .lineLimit(1)
            Button {
                guestEmails.removeAll { $0 == email }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(MadoColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(MadoColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
    }

    private func addGuest() {
        let trimmed = guestInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, trimmed.contains("@"), !guestEmails.contains(trimmed) else {
            guestInput = ""
            return
        }
        guestEmails.append(trimmed)
        guestInput = ""
        guestFieldFocused = true
    }

    // MARK: - Save

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            viewModel.cancelEventCreation()
            return
        }

        let cal = Calendar.current
        let finalStart: Date
        let finalEnd: Date

        if isAllDay {
            finalStart = cal.startOfDay(for: startDate)
            finalEnd = cal.date(byAdding: .day, value: 1, to: finalStart) ?? finalStart
        } else {
            finalStart = startDate
            finalEnd = endDate
        }

        viewModel.createEventWithDetails(
            title: trimmed,
            startDate: finalStart,
            endDate: finalEnd,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes,
            isAllDay: isAllDay,
            guestEmails: guestEmails.isEmpty ? nil : guestEmails,
            addMeetLink: addMeetLink
        )
    }

    private func saveAsTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            viewModel.cancelEventCreation()
            return
        }
        todoVM.addTask(title: trimmed, dueDate: startDate)
        viewModel.cancelEventCreation()
    }

    // MARK: - Formatters

    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        return fmt.string(from: date)
    }
}

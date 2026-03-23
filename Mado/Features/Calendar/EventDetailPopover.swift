import SwiftUI

struct EventDetailPopover: View {
    let event: CalendarEvent
    @Bindable var viewModel: CalendarViewModel

    @State private var isEditing = false
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var location = ""
    @State private var notes = ""
    @State private var isAllDay = false
    @FocusState private var titleFocused: Bool

    private static let colorIdMap: [String: String] = [
        "1": "7986CB", "2": "33B679", "3": "8E24AA", "4": "E67C73",
        "5": "F6BF26", "6": "F4511E", "7": "039BE5", "8": "616161",
        "9": "3F51B5", "10": "0B8043", "11": "D50000",
    ]

    private var eventColor: Color {
        viewModel.colorForEvent(event)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider().foregroundColor(MadoColors.divider)

            if isEditing {
                editContent
            } else {
                viewContent
            }
        }
        .frame(width: 320)
        .background(MadoColors.surface)
        .onAppear { resetFields() }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: MadoTheme.Spacing.xs) {
            Circle().fill(eventColor).frame(width: 10, height: 10)

            Spacer()

            if isEditing {
                Button("Cancel") {
                    isEditing = false
                    resetFields()
                }
                .font(MadoTheme.Font.caption)
                .foregroundColor(MadoColors.textSecondary)
                .buttonStyle(.plain)

                Button("Save") { saveChanges() }
                    .font(MadoTheme.Font.captionMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, MadoTheme.Spacing.sm)
                    .padding(.vertical, MadoTheme.Spacing.xxs)
                    .background(MadoColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
                    .buttonStyle(.plain)
            } else {
                iconButton(icon: "pencil", color: MadoColors.textSecondary) {
                    isEditing = true
                    titleFocused = true
                }
                iconButton(icon: "trash", color: MadoColors.error) {
                    viewModel.editingEvent = nil
                    viewModel.deleteEvent(event)
                }
                iconButton(icon: "xmark", color: MadoColors.textTertiary) {
                    viewModel.editingEvent = nil
                }
            }
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
    }

    private func iconButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
    }

    // MARK: - View Content (Rich Detail)

    private var viewContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: MadoTheme.Spacing.sm) {
                // Title
                Text(event.title)
                    .font(MadoTheme.Font.headline)
                    .foregroundColor(MadoColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // Date & Time
                dateTimeSection

                // RSVP controls
                if let selfAttendee = event.attendees.first(where: { $0.isSelf }) {
                    rsvpControls(currentStatus: selfAttendee.responseStatus)
                }

                // Google Meet / Conference link
                if event.hasConference {
                    conferenceSection
                }

                // Location
                if let loc = event.location, !loc.isEmpty {
                    detailRow(icon: "mappin.and.ellipse") {
                        linkedText(loc)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Description / Notes
                if let n = event.notes, !n.isEmpty {
                    detailRow(icon: "text.alignleft") {
                        linkedText(n)
                            .lineLimit(8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Organizer
                if let orgEmail = event.organizerEmail, !orgEmail.isEmpty {
                    organizerSection(email: orgEmail, name: event.organizerName)
                }

                // Attendees
                if !event.attendees.isEmpty {
                    attendeesSection
                }

                // Open in Google Calendar
                if let htmlLink = event.htmlLink, let url = URL(string: htmlLink) {
                    Divider().foregroundColor(MadoColors.divider)
                    Button {
                        openExternalURL(url)
                    } label: {
                        HStack(spacing: MadoTheme.Spacing.xs) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                            Text("Open in Google Calendar")
                                .font(MadoTheme.Font.caption)
                        }
                        .foregroundColor(MadoColors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(MadoTheme.Spacing.md)
        }
        .frame(maxHeight: 400)
    }

    // MARK: - Date & Time Section

    private var dateTimeSection: some View {
        detailRow(icon: "clock") {
            if event.isAllDay {
                dateTimePill(text: "\(formatDate(event.startDate)) · All day")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    dateTimePill(text: formatDate(event.startDate))
                    Text("\(formatTime(event.startDate)) – \(formatTime(event.endDate))")
                        .font(MadoTheme.Font.caption)
                        .foregroundColor(MadoColors.textTertiary)
                }
            }
        }
    }

    private func dateTimePill(text: String) -> some View {
        Text(text)
            .font(MadoTheme.Font.captionMedium)
            .foregroundColor(MadoColors.textPrimary)
            .padding(.horizontal, MadoTheme.Spacing.sm)
            .padding(.vertical, MadoTheme.Spacing.xxs)
            .background(MadoColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
    }

    // MARK: - RSVP Controls

    private func rsvpControls(currentStatus: String) -> some View {
        HStack(spacing: MadoTheme.Spacing.xs) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 11))
                .foregroundColor(MadoColors.textTertiary)
                .frame(width: 14)

            rsvpButton(label: "Yes", icon: "checkmark", status: "accepted", current: currentStatus, color: MadoColors.success)
            rsvpButton(label: "Maybe", icon: "questionmark", status: "tentative", current: currentStatus, color: MadoColors.warning)
            rsvpButton(label: "No", icon: "xmark", status: "declined", current: currentStatus, color: MadoColors.error)

            Spacer()
        }
    }

    private func rsvpButton(label: String, icon: String, status: String, current: String, color: Color) -> some View {
        let isActive = current == status
        let isRecurring = viewModel.isRecurringEvent(event)

        return Group {
            if isRecurring {
                Menu {
                    Button("This event") {
                        viewModel.rsvpToEvent(event, response: status, applyToSeries: false)
                    }
                    Button("All events") {
                        viewModel.rsvpToEvent(event, response: status, applyToSeries: true)
                    }
                } label: {
                    rsvpLabel(icon: icon, label: label, isActive: isActive, color: color)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            } else {
                Button {
                    viewModel.rsvpToEvent(event, response: status)
                } label: {
                    rsvpLabel(icon: icon, label: label, isActive: isActive, color: color)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func rsvpLabel(icon: String, label: String, isActive: Bool, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(MadoTheme.Font.captionMedium)
        }
        .foregroundColor(isActive ? .white : color)
        .padding(.horizontal, MadoTheme.Spacing.sm)
        .padding(.vertical, MadoTheme.Spacing.xxs)
        .background(isActive ? color : color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
    }

    // MARK: - Linked Text (clickable URLs)

    private func linkedText(_ text: String) -> some View {
        let attributed = makeLinkedAttributedString(text)
        return Text(attributed)
    }

    private func makeLinkedAttributedString(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        result.font = MadoTheme.Font.body
        result.foregroundColor = MadoColors.textSecondary

        // Find URLs using NSDataDetector
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return result
        }
        let nsString = text as NSString
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            guard let range = Range(match.range, in: text),
                  let attrRange = Range(match.range, in: result),
                  let url = match.url else { continue }
            result[attrRange].link = url
            result[attrRange].foregroundColor = MadoColors.accent
            result[attrRange].underlineStyle = .single
        }

        return result
    }

    // MARK: - Conference / Google Meet Section

    private var conferenceSection: some View {
        Button {
            if let urlStr = event.conferenceURL, let url = URL(string: urlStr) {
                openExternalURL(url)
            }
        } label: {
            HStack(spacing: MadoTheme.Spacing.sm) {
                Image(systemName: "video.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color(hex: "00897B"))
                    .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Join \(event.conferenceName ?? "Meeting")")
                        .font(MadoTheme.Font.captionMedium)
                        .foregroundColor(MadoColors.textPrimary)

                    if let urlStr = event.conferenceURL {
                        let shortUrl = urlStr
                            .replacingOccurrences(of: "https://", with: "")
                            .prefix(35)
                        Text(shortUrl)
                            .font(MadoTheme.Font.tiny)
                            .foregroundColor(MadoColors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundColor(MadoColors.textTertiary)
            }
            .padding(MadoTheme.Spacing.sm)
            .background(MadoColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Organizer Section

    private func organizerSection(email: String, name: String?) -> some View {
        detailRow(icon: "person.fill") {
            HStack(spacing: MadoTheme.Spacing.xs) {
                Text(name ?? email)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textSecondary)

                Text("Organizer")
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(MadoColors.textTertiary)
                    .padding(.horizontal, MadoTheme.Spacing.xxs + 2)
                    .padding(.vertical, 1)
                    .background(MadoColors.surfaceTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.xs))
            }
        }
    }

    // MARK: - Attendees Section

    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: MadoTheme.Spacing.xs) {
            Divider().foregroundColor(MadoColors.divider)

            HStack(spacing: MadoTheme.Spacing.xs) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(MadoColors.textTertiary)
                    .frame(width: 14)

                Text("\(event.attendees.count) guest\(event.attendees.count == 1 ? "" : "s")")
                    .font(MadoTheme.Font.captionMedium)
                    .foregroundColor(MadoColors.textSecondary)

                Spacer()

                // RSVP summary
                rsvpSummary
            }

            ForEach(event.attendees) { attendee in
                attendeeRow(attendee)
            }
        }
    }

    private var rsvpSummary: some View {
        let accepted = event.attendees.filter { $0.responseStatus == "accepted" }.count
        let declined = event.attendees.filter { $0.responseStatus == "declined" }.count
        let pending = event.attendees.count - accepted - declined

        return HStack(spacing: MadoTheme.Spacing.xs) {
            if accepted > 0 {
                rsvpBadge(count: accepted, icon: "checkmark", color: MadoColors.success)
            }
            if declined > 0 {
                rsvpBadge(count: declined, icon: "xmark", color: MadoColors.error)
            }
            if pending > 0 {
                rsvpBadge(count: pending, icon: "questionmark", color: MadoColors.textTertiary)
            }
        }
    }

    private func rsvpBadge(count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text("\(count)")
                .font(MadoTheme.Font.tiny)
        }
        .foregroundColor(color)
    }

    private func attendeeRow(_ attendee: EventAttendee) -> some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            // Status icon
            Image(systemName: attendee.statusIcon)
                .font(.system(size: 11))
                .foregroundColor(attendeeStatusColor(attendee.responseStatus))

            // Avatar circle with initial
            let initial = String((attendee.displayName ?? attendee.email).prefix(1)).uppercased()
            Text(initial)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(avatarColor(for: attendee.email))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: MadoTheme.Spacing.xxs) {
                    Text(attendee.displayLabel)
                        .font(MadoTheme.Font.caption)
                        .foregroundColor(MadoColors.textPrimary)
                        .lineLimit(1)

                    if attendee.isOrganizer {
                        Text("organizer")
                            .font(.system(size: 9))
                            .foregroundColor(MadoColors.textTertiary)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(MadoColors.surfaceTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }

                    if attendee.isSelf {
                        Text("you")
                            .font(.system(size: 9))
                            .foregroundColor(MadoColors.accent)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(MadoColors.accentLight)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }

                if attendee.displayName != nil {
                    Text(attendee.email)
                        .font(MadoTheme.Font.tiny)
                        .foregroundColor(MadoColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(attendee.statusLabel)
                .font(MadoTheme.Font.tiny)
                .foregroundColor(attendeeStatusColor(attendee.responseStatus))
        }
        .padding(.vertical, 2)
        .padding(.leading, MadoTheme.Spacing.lg + MadoTheme.Spacing.xs)
    }

    private func attendeeStatusColor(_ status: String) -> Color {
        switch status {
        case "accepted": return MadoColors.success
        case "declined": return MadoColors.error
        case "tentative": return MadoColors.warning
        default: return MadoColors.textTertiary
        }
    }

    private func avatarColor(for email: String) -> Color {
        let colors: [Color] = [
            Color(hex: "4A90D9"), Color(hex: "7B68EE"), Color(hex: "E67E22"),
            Color(hex: "27AE60"), Color(hex: "EB5757"), Color(hex: "8E44AD"),
            Color(hex: "2980B9"), Color(hex: "D35400"), Color(hex: "16A085"),
        ]
        let hash = abs(email.hashValue)
        return colors[hash % colors.count]
    }

    // MARK: - Detail Row Helper

    private func detailRow<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: MadoTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(MadoColors.textTertiary)
                .frame(width: 14, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                content()
            }
            .font(MadoTheme.Font.body)
            .foregroundColor(MadoColors.textSecondary)
        }
    }

    // MARK: - Edit Content

    private var editContent: some View {
        VStack(alignment: .leading, spacing: MadoTheme.Spacing.md) {
            TextField("Event title", text: $title)
                .textFieldStyle(.plain)
                .font(MadoTheme.Font.headline)
                .foregroundColor(MadoColors.textPrimary)
                .focused($titleFocused)
                .onSubmit { saveChanges() }

            Divider().foregroundColor(MadoColors.divider)

            Toggle("All day", isOn: $isAllDay)
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textSecondary)
                .toggleStyle(.switch)
                .controlSize(.small)

            if isAllDay {
                DatePicker("Date", selection: $startDate, displayedComponents: .date)
                    .font(MadoTheme.Font.body)
            } else {
                VStack(alignment: .leading, spacing: MadoTheme.Spacing.xs) {
                    DatePicker("Start", selection: $startDate)
                        .font(MadoTheme.Font.body)
                    DatePicker("End", selection: $endDate)
                        .font(MadoTheme.Font.body)
                }
            }

            Divider().foregroundColor(MadoColors.divider)

            HStack(spacing: MadoTheme.Spacing.sm) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 11))
                    .foregroundColor(MadoColors.textTertiary)
                    .frame(width: 14)
                TextField("Location", text: $location)
                    .textFieldStyle(.plain)
                    .font(MadoTheme.Font.body)
            }

            HStack(alignment: .top, spacing: MadoTheme.Spacing.sm) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 11))
                    .foregroundColor(MadoColors.textTertiary)
                    .frame(width: 14)
                    .padding(.top, 2)
                TextField("Notes", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(MadoTheme.Font.body)
                    .lineLimit(1...5)
            }
        }
        .padding(MadoTheme.Spacing.md)
    }

    // MARK: - Actions

    private func saveChanges() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let cal = Calendar.current
        let finalStart = isAllDay ? cal.startOfDay(for: startDate) : startDate
        let finalEnd = isAllDay
            ? (cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: startDate)) ?? endDate)
            : endDate

        viewModel.updateEvent(
            event,
            title: trimmed,
            startDate: finalStart,
            endDate: finalEnd,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes,
            isAllDay: isAllDay
        )
    }

    private func resetFields() {
        title = event.title
        startDate = event.startDate
        endDate = event.endDate
        location = event.location ?? ""
        notes = event.notes ?? ""
        isAllDay = event.isAllDay
    }

    // MARK: - Formatters

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d, yyyy"
        return fmt.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        if AppSettings.shared.use24HourTime {
            fmt.dateFormat = "HH:mm"
        } else {
            fmt.dateFormat = "h:mm a"
        }
        let str = fmt.string(from: date)
        // Lowercase am/pm
        return str.replacingOccurrences(of: "AM", with: "am")
            .replacingOccurrences(of: "PM", with: "pm")
    }
}

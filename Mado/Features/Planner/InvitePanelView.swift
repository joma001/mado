import SwiftUI

struct InvitePanelView: View {
    var calendarVM: CalendarViewModel

    @State private var isResponding: String?

    private let calendarService = GoogleCalendarService()
    private let data = DataController.shared
    private let sync = SyncEngine.shared

    private var allInviteEvents: [CalendarEvent] {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let oneYearAhead = Calendar.current.date(byAdding: .year, value: 1, to: now)!
        let selectedIds = (try? data.fetchSelectedCalendarIds()) ?? []
        let events = (try? data.fetchEvents(from: thirtyDaysAgo, to: oneYearAhead, calendarIds: selectedIds)) ?? []
        return events.filter { !$0.attendees.isEmpty }
    }

    private var pendingInvites: [CalendarEvent] {
        let now = Date()
        return allInviteEvents.filter { event in
            event.startDate >= now &&
            event.attendees.contains { $0.isSelf && $0.responseStatus == "needsAction" }
        }
        .sorted { $0.startDate < $1.startDate }
    }

    private var recentlyActioned: [CalendarEvent] {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let selectedIds = (try? data.fetchSelectedCalendarIds()) ?? []
        let events = (try? data.fetchEvents(from: sevenDaysAgo, to: now, calendarIds: selectedIds)) ?? []
        return events
            .filter { $0.startDate < now }
            .sorted { $0.startDate > $1.startDate }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().foregroundColor(MadoColors.divider)

            ScrollView {
                VStack(spacing: 0) {
                    if pendingInvites.isEmpty && recentlyActioned.isEmpty {
                        emptyState
                    } else {
                        if !pendingInvites.isEmpty {
                            inviteList
                        } else {
                            noPendingState
                        }

                        if !recentlyActioned.isEmpty {
                            recentSection
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)
        .background(MadoColors.sidebar)
    }

    private var header: some View {
        HStack {
            Text("Invites")
                .font(MadoTheme.Font.headline)
                .foregroundColor(MadoColors.textPrimary)

            Text("\(pendingInvites.count)")
                .font(MadoTheme.Font.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(pendingInvites.isEmpty ? MadoColors.textTertiary : MadoColors.accent)
                )

            Spacer()
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
    }

    private var emptyState: some View {
        VStack(spacing: MadoTheme.Spacing.sm) {
            Image(systemName: "envelope.open")
                .font(.system(size: 28))
                .foregroundColor(MadoColors.textTertiary.opacity(0.5))
            Text("No pending invites")
                .font(MadoTheme.Font.caption)
                .foregroundColor(MadoColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MadoTheme.Spacing.xxxxl)
    }

    private var noPendingState: some View {
        HStack(spacing: MadoTheme.Spacing.xs) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 12))
                .foregroundColor(MadoColors.success)
            Text("No pending invites")
                .font(MadoTheme.Font.caption)
                .foregroundColor(MadoColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
    }

    private var inviteList: some View {
        LazyVStack(spacing: MadoTheme.Spacing.sm) {
            ForEach(pendingInvites, id: \.id) { event in
                InviteCard(
                    event: event,
                    calendarColor: calendarVM.colorForEvent(event),
                    isResponding: isResponding == event.id,
                    onRespond: { response, applyToSeries in
                        respondToInvite(event: event, response: response, applyToSeries: applyToSeries)
                    }
                )
            }
        }
        .padding(MadoTheme.Spacing.sm)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: MadoTheme.Spacing.xs) {
            Text("Recent")
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(MadoColors.textTertiary)
                .padding(.horizontal, MadoTheme.Spacing.md)
                .padding(.top, MadoTheme.Spacing.sm)

            LazyVStack(spacing: 2) {
                ForEach(recentlyActioned, id: \.id) { event in
                    ActionedInviteRow(
                        event: event,
                        calendarColor: calendarVM.colorForEvent(event),
                        onConvertToTask: {
                            calendarVM.createTaskFromEvent(event)
                        }
                    )
                }
            }
            .padding(.horizontal, MadoTheme.Spacing.sm)
            .padding(.bottom, MadoTheme.Spacing.sm)
        }
    }

    private func respondToInvite(event: CalendarEvent, response: String, applyToSeries: Bool = false) {
        isResponding = event.id
        Task {
            do {
                let updatedAttendees = event.attendees.map { attendee -> GoogleAttendeeDTO in
                    GoogleAttendeeDTO(
                        email: attendee.email,
                        displayName: attendee.displayName,
                        responseStatus: attendee.isSelf ? response : attendee.responseStatus,
                        organizer: attendee.isOrganizer,
                        self: attendee.isSelf
                    )
                }

                let targetEventId = applyToSeries ? (event.recurringEventId ?? event.googleEventId) : event.googleEventId
                let rsvpAccountEmail = event.accountEmail.isEmpty ? nil : event.accountEmail
                let _ = try await calendarService.rsvpEvent(
                    calendarId: event.calendarId,
                    eventId: targetEventId,
                    attendees: updatedAttendees,
                    accountEmail: rsvpAccountEmail
                )

                let updatedLocal = event.attendees.map { a in
                    EventAttendee(
                        email: a.email,
                        displayName: a.displayName,
                        responseStatus: a.isSelf ? response : a.responseStatus,
                        isOrganizer: a.isOrganizer,
                        isSelf: a.isSelf
                    )
                }
                event.attendeesJSON = try? JSONEncoder().encode(updatedLocal)
                event.localUpdatedAt = Date()

                if applyToSeries, let seriesId = event.recurringEventId {
                    let allInstances = (try? data.fetchEventsBySeries(recurringEventId: seriesId)) ?? []
                    for instance in allInstances where instance.id != event.id {
                        var instAttendees = instance.attendees
                        if let idx = instAttendees.firstIndex(where: { $0.isSelf }) {
                            instAttendees[idx] = EventAttendee(
                                email: instAttendees[idx].email,
                                displayName: instAttendees[idx].displayName,
                                responseStatus: response,
                                isOrganizer: instAttendees[idx].isOrganizer,
                                isSelf: true
                            )
                            instance.attendeesJSON = try? JSONEncoder().encode(instAttendees)
                            instance.localUpdatedAt = Date()
                        }
                    }
                }

                data.save()
                calendarVM.loadEvents()
            } catch {
                NSLog("[InvitePanel] RSVP failed: %@", error.localizedDescription)
            }
            isResponding = nil
        }
    }
}

private struct InviteCard: View {
    let event: CalendarEvent
    let calendarColor: Color
    let isResponding: Bool
    let onRespond: (String, Bool) -> Void

    @State private var isHovered = false

    private var organizer: String {
        event.organizerName ?? event.organizerEmail ?? "Unknown"
    }

    private var timeText: String {
        let fmt = DateFormatter()
        let use24 = AppSettings.shared.use24HourTime

        if event.isAllDay {
            fmt.dateFormat = "MMM d"
            return fmt.string(from: event.startDate)
        }

        let cal = Calendar.current
        if cal.isDateInToday(event.startDate) {
            fmt.dateFormat = use24 ? "HH:mm" : "h:mm a"
            let start = fmt.string(from: event.startDate)
            let end = fmt.string(from: event.endDate)
            let result = "Today, \(start) – \(end)"
            return use24 ? result : result.replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
        }

        if cal.isDateInTomorrow(event.startDate) {
            fmt.dateFormat = use24 ? "HH:mm" : "h:mm a"
            let start = fmt.string(from: event.startDate)
            let end = fmt.string(from: event.endDate)
            let result = "Tomorrow, \(start) – \(end)"
            return use24 ? result : result.replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
        }

        fmt.dateFormat = use24 ? "MMM d, HH:mm" : "MMM d, h:mm a"
        let start = fmt.string(from: event.startDate)
        fmt.dateFormat = use24 ? "HH:mm" : "h:mm a"
        let end = fmt.string(from: event.endDate)
        let result = "\(start) – \(end)"
        return use24 ? result : result.replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
    }

    private var attendeeCount: Int {
        event.attendees.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MadoTheme.Spacing.xs) {
            HStack(spacing: MadoTheme.Spacing.xs) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(calendarColor)
                    .frame(width: 4, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(MadoTheme.Font.bodyMedium)
                        .foregroundColor(MadoColors.textPrimary)
                        .lineLimit(2)

                    Text(timeText)
                        .font(MadoTheme.Font.caption)
                        .foregroundColor(MadoColors.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: MadoTheme.Spacing.xs) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                    .foregroundColor(MadoColors.textTertiary)
                Text(organizer)
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(MadoColors.textTertiary)
                    .lineLimit(1)

                if attendeeCount > 1 {
                    Text("+ \(attendeeCount - 1)")
                        .font(.system(size: 9))
                        .foregroundColor(MadoColors.textTertiary)
                }
            }

            if let location = event.location, !location.isEmpty {
                HStack(spacing: MadoTheme.Spacing.xs) {
                    Image(systemName: "mappin")
                        .font(.system(size: 9))
                        .foregroundColor(MadoColors.textTertiary)
                    Text(location)
                        .font(MadoTheme.Font.tiny)
                        .foregroundColor(MadoColors.textTertiary)
                        .lineLimit(1)
                }
            }

            if event.hasConference {
                HStack(spacing: MadoTheme.Spacing.xs) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 9))
                        .foregroundColor(MadoColors.accent)
                    Text(event.conferenceName ?? "Video call")
                        .font(MadoTheme.Font.tiny)
                        .foregroundColor(MadoColors.accent)
                }
            }

            Divider().foregroundColor(MadoColors.divider)

            if isResponding {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                    Spacer()
                }
                .frame(height: 28)
            } else {
                HStack(spacing: MadoTheme.Spacing.xs) {
                    rsvpButton(label: "Accept", icon: "checkmark", response: "accepted", color: MadoColors.success)
                    rsvpButton(label: "Maybe", icon: "questionmark", response: "tentative", color: MadoColors.warning)
                    rsvpButton(label: "Decline", icon: "xmark", response: "declined", color: MadoColors.error)
                }
            }
        }
        .padding(MadoTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.md)
                .fill(MadoColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.md)
                .stroke(isHovered ? MadoColors.borderHover : MadoColors.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

    private var isRecurring: Bool {
        event.recurringEventId != nil && !(event.recurringEventId?.isEmpty ?? true)
    }

    @ViewBuilder
    private func rsvpButton(label: String, icon: String, response: String, color: Color) -> some View {
        if isRecurring {
            Menu {
                Button("This event") { onRespond(response, false) }
                Button("All events") { onRespond(response, true) }
            } label: {
                rsvpButtonLabel(icon: icon, label: label, color: color)
            }
            .menuStyle(.borderlessButton)
        } else {
            Button {
                onRespond(response, false)
            } label: {
                rsvpButtonLabel(icon: icon, label: label, color: color)
            }
            .buttonStyle(.plain)
        }
    }

    private func rsvpButtonLabel(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(MadoTheme.Font.captionMedium)
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, MadoTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                .fill(color.opacity(0.1))
        )
    }
}

private struct ActionedInviteRow: View {
    let event: CalendarEvent
    let calendarColor: Color
    var onConvertToTask: () -> Void = {}
    @State private var isHovered = false
    @State private var convertedToTask = false

    private var selfResponse: String {
        event.attendees.first(where: \.isSelf)?.responseStatus ?? ""
    }

    private var statusIcon: String {
        switch selfResponse {
        case "accepted": return "checkmark.circle.fill"
        case "declined": return "xmark.circle.fill"
        case "tentative": return "questionmark.circle.fill"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch selfResponse {
        case "accepted": return MadoColors.success
        case "declined": return MadoColors.error
        case "tentative": return MadoColors.warning
        default: return MadoColors.textTertiary
        }
    }

    private var timeText: String {
        let fmt = DateFormatter()
        let use24 = AppSettings.shared.use24HourTime
        let cal = Calendar.current

        if cal.isDateInToday(event.startDate) {
            fmt.dateFormat = use24 ? "HH:mm" : "h:mm a"
            return "Today, \(fmt.string(from: event.startDate))"
        }
        if cal.isDateInTomorrow(event.startDate) {
            fmt.dateFormat = use24 ? "HH:mm" : "h:mm a"
            return "Tomorrow, \(fmt.string(from: event.startDate))"
        }
        fmt.dateFormat = use24 ? "MMM d, HH:mm" : "MMM d, h:mm a"
        return fmt.string(from: event.startDate)
    }

    var body: some View {
        HStack(spacing: MadoTheme.Spacing.xs) {
            Image(systemName: statusIcon)
                .font(.system(size: 11))
                .foregroundColor(statusColor)

            RoundedRectangle(cornerRadius: 2)
                .fill(calendarColor)
                .frame(width: 3, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(MadoTheme.Font.caption)
                    .foregroundColor(MadoColors.textPrimary)
                    .lineLimit(1)

                Text(timeText)
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(MadoColors.textTertiary)
            }

            Spacer()

            Button {
                guard !convertedToTask else { return }
                onConvertToTask()
                withAnimation(.easeInOut(duration: 0.2)) {
                    convertedToTask = true
                }
            } label: {
                Image(systemName: convertedToTask ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 13))
                    .foregroundColor(convertedToTask ? MadoColors.success : MadoColors.accent.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help(convertedToTask ? "Added to tasks" : "Add to tasks")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, MadoTheme.Spacing.xs)
        .background(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm).fill(isHovered ? MadoColors.hoverBackground : Color.clear))
        .onHover { isHovered = $0 }
    }
}

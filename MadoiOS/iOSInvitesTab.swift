import os
import SwiftUI

struct iOSInvitesTab: View {
    @Bindable var viewModel = CalendarViewModel()
    @State private var respondingId: String?
    
    private let calendarService = GoogleCalendarService()
    private let data = DataController.shared
    
    private var pendingInvites: [CalendarEvent] {
        viewModel.events.filter { event in
            event.attendees.contains { $0.isSelf && $0.responseStatus == "needsAction" }
        }
        .sorted { $0.startDate < $1.startDate }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if pendingInvites.isEmpty {
                    emptyState
                } else {
                    inviteList
                }
            }
            .navigationTitle("Invites")
            .onAppear { loadInvites() }
            .refreshable { loadInvites() }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "envelope.open")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(MadoColors.textTertiary.opacity(0.5))
            Text("No pending invites")
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textSecondary)
            Text("Calendar invitations will appear here")
                .font(MadoTheme.Font.tiny)
                .foregroundColor(MadoColors.textTertiary)
            Spacer()
        }
    }
    
    // MARK: - Invite List
    
    private var inviteList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(pendingInvites, id: \.id) { event in
                    iOSInviteCard(
                        event: event,
                        calendarColor: viewModel.calendarColorMap[event.calendarId] ?? MadoColors.calendarDefault,
                        isResponding: respondingId == event.id,
                        onRespond: { response in
                            respondToInvite(event: event, response: response)
                        }
                    )
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Actions
    
    private func loadInvites() {
        // Load events for the next 30 days to find all pending invites
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 30, to: start)!
        
        viewModel.isLoading = true
        do {
            let selectedIds = try DataController.shared.fetchSelectedCalendarIds()
            
            let calendars = try DataController.shared.fetchCalendars()
            var colorMap: [String: Color] = [:]
            for c in calendars { colorMap[c.googleCalendarId] = c.displayColor }
            viewModel.calendarColorMap = colorMap
            
            let allEvents = try DataController.shared.fetchEvents(from: start, to: end, calendarIds: selectedIds)
            viewModel.events = allEvents.filter { $0.sourceTaskId == nil }
            viewModel.isLoading = false
        } catch {
            viewModel.isLoading = false
            MadoLogger.general.error("Invites failed to load: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func respondToInvite(event: CalendarEvent, response: String) {
        respondingId = event.id
        Task {
            do {
                let updatedAttendees = event.attendees.map { attendee in
                    GoogleAttendeeDTO(
                        email: attendee.email,
                        displayName: attendee.displayName,
                        responseStatus: attendee.isSelf ? response : attendee.responseStatus,
                        organizer: attendee.isOrganizer,
                        self: attendee.isSelf
                    )
                }
                
                let rsvpAccountEmail = event.accountEmail.isEmpty ? nil : event.accountEmail
                let _ = try await calendarService.rsvpEvent(
                    calendarId: event.calendarId,
                    eventId: event.googleEventId,
                    attendees: updatedAttendees,
                    accountEmail: rsvpAccountEmail
                )
                
                // Update local data
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
                data.save()
                
                loadInvites()
            } catch {
                MadoLogger.general.error("Invites RSVP failed: \(error.localizedDescription, privacy: .public)")
            }
            respondingId = nil
        }
    }
}

// MARK: - Invite Card

private struct iOSInviteCard: View {
    let event: CalendarEvent
    let calendarColor: Color
    let isResponding: Bool
    let onRespond: (String) -> Void
    
    private var organizer: String {
        event.organizerName ?? event.organizerEmail ?? "Unknown"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Event info
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(calendarColor)
                    .frame(width: 4, height: 44)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(MadoColors.textPrimary)
                        .lineLimit(2)
                    
                    Text(timeText)
                        .font(.system(size: 13))
                        .foregroundColor(MadoColors.textSecondary)
                }
                
                Spacer()
            }
            
            // Metadata row
            HStack(spacing: 12) {
                // Organizer
                Label(organizer, systemImage: "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(MadoColors.textTertiary)
                    .lineLimit(1)
                
                if event.attendees.count > 1 {
                    Text("\(event.attendees.count) people")
                        .font(.system(size: 12))
                        .foregroundColor(MadoColors.textTertiary)
                }
            }
            
            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin")
                    .font(.system(size: 12))
                    .foregroundColor(MadoColors.textTertiary)
                    .lineLimit(1)
            }
            
            if event.hasConference {
                Label(event.conferenceName ?? "Video call", systemImage: "video.fill")
                    .font(.system(size: 12))
                    .foregroundColor(MadoColors.accent)
            }
            
            Divider()
            
            // RSVP buttons
            if isResponding {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 36)
            } else {
                HStack(spacing: 8) {
                    rsvpButton(label: "Accept", icon: "checkmark", response: "accepted", color: Color(hex: "0B8043") ?? .green)
                    rsvpButton(label: "Maybe", icon: "questionmark", response: "tentative", color: Color(hex: "F4B400") ?? .orange)
                    rsvpButton(label: "Decline", icon: "xmark", response: "declined", color: Color(hex: "D93025") ?? .red)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MadoColors.border, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func rsvpButton(label: String, icon: String, response: String, color: Color) -> some View {
        Button {
            onRespond(response)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
            )
        }
    }
    
    private var timeText: String {
        if event.isAllDay {
            return DateFormatters.shortDayDate.string(from: event.startDate)
        }

        let cal = Calendar.current
        let startTime = DateFormatters.time12h.string(from: event.startDate)
        let endTime = DateFormatters.time12h.string(from: event.endDate)
        if cal.isDateInToday(event.startDate) {
            return "Today, \(startTime) – \(endTime)"
        }
        if cal.isDateInTomorrow(event.startDate) {
            return "Tomorrow, \(startTime) – \(endTime)"
        }

        let start = DateFormatters.dayDateTimeComma.string(from: event.startDate)
        return "\(start) – \(endTime)"
    }
}

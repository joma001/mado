import SwiftUI

struct iOSEventDetailView: View {
    let event: CalendarEvent
    let viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(event.title)
                        .font(MadoTheme.Font.title)
                        .foregroundColor(MadoColors.textPrimary)

                    // Time
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(MadoColors.textSecondary)
                        if event.isAllDay {
                            Text("All day")
                                .font(MadoTheme.Font.body)
                        } else {
                            Text(timeRangeText)
                                .font(MadoTheme.Font.body)
                        }
                    }
                    .foregroundColor(MadoColors.textSecondary)

                    // Location
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(MadoColors.textSecondary)
                            Text(location)
                                .font(MadoTheme.Font.body)
                                .foregroundColor(MadoColors.textPrimary)
                        }
                    }

                    // Conference link
                    if let confURL = event.conferenceURL, let url = URL(string: confURL) {
                        Button {
                            openURL(url)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                Text(event.conferenceName ?? "Join Meeting")
                            }
                            .font(MadoTheme.Font.bodyMedium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(MadoColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Attendees
                    if !event.attendees.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Attendees")
                                .font(MadoTheme.Font.captionMedium)
                                .foregroundColor(MadoColors.textTertiary)

                            ForEach(event.attendees) { attendee in
                                HStack(spacing: 8) {
                                    Image(systemName: attendee.statusIcon)
                                        .font(.system(size: 14))
                                        .foregroundColor(attendeeColor(attendee.responseStatus))
                                    Text(attendee.displayLabel)
                                        .font(MadoTheme.Font.body)
                                        .foregroundColor(MadoColors.textPrimary)
                                    if attendee.isOrganizer {
                                        Text("Organizer")
                                            .font(MadoTheme.Font.tiny)
                                            .foregroundColor(MadoColors.textTertiary)
                                    }
                                }
                            }
                        }
                    }

                    // RSVP
                    if event.attendees.contains(where: { $0.isSelf }) {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Response")
                                .font(MadoTheme.Font.captionMedium)
                                .foregroundColor(MadoColors.textTertiary)

                            HStack(spacing: 12) {
                                rsvpButton("Yes", response: "accepted", icon: "checkmark.circle.fill")
                                rsvpButton("Maybe", response: "tentative", icon: "questionmark.circle.fill")
                                rsvpButton("No", response: "declined", icon: "xmark.circle.fill")
                            }
                        }
                    }

                    // Notes
                    if let notes = event.notes, !notes.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(MadoTheme.Font.captionMedium)
                                .foregroundColor(MadoColors.textTertiary)
                            Text(notes)
                                .font(MadoTheme.Font.body)
                                .foregroundColor(MadoColors.textPrimary)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var timeRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d · h:mm a"
        let start = fmt.string(from: event.startDate)
        fmt.dateFormat = "h:mm a"
        let end = fmt.string(from: event.endDate)
        return "\(start) – \(end)"
    }

    private func attendeeColor(_ status: String) -> Color {
        switch status {
        case "accepted": return MadoColors.success
        case "declined": return MadoColors.error
        case "tentative": return MadoColors.warning
        default: return MadoColors.textTertiary
        }
    }

    @ViewBuilder
    private func rsvpButton(_ label: String, response: String, icon: String) -> some View {
        let currentResponse = event.attendees.first(where: { $0.isSelf })?.responseStatus
        let isActive = currentResponse == response

        Button {
            viewModel.rsvpToEvent(event, response: response)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(MadoTheme.Font.captionMedium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(isActive ? .white : MadoColors.textSecondary)
            .background(isActive ? MadoColors.accent : MadoColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

import Foundation
import SwiftData

@Model
final class CalendarEvent {
    @Attribute(.unique) var id: String = UUID().uuidString
    var googleEventId: String = ""
    var calendarId: String = ""
    var accountEmail: String = ""

    var title: String = ""
    var notes: String?
    var location: String?

    // Time
    var startDate: Date = Date()
    var endDate: Date = Date()
    var isAllDay: Bool = false

    // Recurrence
    var recurrenceRules: [String]?
    var recurringEventId: String?

    // Metadata
    var etag: String?
    var colorId: String?
    var googleUpdatedAt: Date?
    var localUpdatedAt: Date = Date()
    var isDeleted: Bool = false
    var needsSync: Bool = false

    // Created from a task drag-and-drop?
    var sourceTaskId: String?


    // Rich detail (synced from Google Calendar API)
    var attendeesJSON: Data?
    var organizerEmail: String?
    var organizerName: String?
    var conferenceURL: String?
    var conferenceName: String?
    var htmlLink: String?
    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    // Computed: decode attendees from JSON
    var attendees: [EventAttendee] {
        guard let data = attendeesJSON else { return [] }
        return (try? JSONDecoder().decode([EventAttendee].self, from: data)) ?? []
    }

    // Computed: user hasn't responded to this invite
    var isPendingInvite: Bool {
        attendees.contains { $0.isSelf && $0.responseStatus == "needsAction" }
    }

    // Computed: user declined this invite
    var isDeclined: Bool {
        attendees.contains { $0.isSelf && $0.responseStatus == "declined" }
    }

    var canEditTime: Bool {
        guard let organizer = organizerEmail, !organizer.isEmpty else { return true }
        return organizer == accountEmail
    }

    // Computed: has conference/meeting link
    var hasConference: Bool {
        conferenceURL != nil && !(conferenceURL?.isEmpty ?? true)
    }

    init(
        id: String = UUID().uuidString,
        googleEventId: String,
        calendarId: String,
        title: String,
        notes: String? = nil,
        location: String? = nil,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        recurrenceRules: [String]? = nil,
        recurringEventId: String? = nil,
        etag: String? = nil,
        colorId: String? = nil,
        sourceTaskId: String? = nil,
        accountEmail: String = ""
    ) {
        self.id = id
        self.googleEventId = googleEventId
        self.calendarId = calendarId
        self.title = title
        self.notes = notes
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.recurrenceRules = recurrenceRules
        self.recurringEventId = recurringEventId
        self.etag = etag
        self.colorId = colorId
        self.sourceTaskId = sourceTaskId
        self.accountEmail = accountEmail
        self.localUpdatedAt = Date()
        self.isDeleted = false
        self.needsSync = false
    }
}

// MARK: - EventAttendee (stored as JSON in CalendarEvent.attendeesJSON)

struct EventAttendee: Codable, Identifiable {
    var id: String { email }
    let email: String
    let displayName: String?
    let responseStatus: String  // "accepted", "declined", "tentative", "needsAction"
    let isOrganizer: Bool
    let isSelf: Bool

    var statusIcon: String {
        switch responseStatus {
        case "accepted": return "checkmark.circle.fill"
        case "declined": return "xmark.circle.fill"
        case "tentative": return "questionmark.circle.fill"
        default: return "circle"
        }
    }

    var statusLabel: String {
        switch responseStatus {
        case "accepted": return "Accepted"
        case "declined": return "Declined"
        case "tentative": return "Maybe"
        case "needsAction": return "Awaiting"
        default: return responseStatus
        }
    }

    var displayLabel: String {
        displayName ?? email
    }
}

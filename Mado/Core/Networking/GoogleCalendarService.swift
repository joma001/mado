import Foundation

struct GoogleCalendarService {
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let client = APIClient.shared

    func listCalendars(accountEmail: String? = nil) async throws -> GoogleCalendarListResponse {
        try await client.get(url: "\(baseURL)/users/me/calendarList", accountEmail: accountEmail)
    }

    func listEvents(
        calendarId: String,
        timeMin: Date,
        timeMax: Date,
        syncToken: String? = nil,
        pageToken: String? = nil,
        accountEmail: String? = nil
    ) async throws -> GoogleEventsResponse {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "250"),
            URLQueryItem(name: "showDeleted", value: "true"),
        ]
        if let syncToken {
            query.append(URLQueryItem(name: "syncToken", value: syncToken))
        } else {
            query.append(URLQueryItem(name: "timeMin", value: ISO8601DateFormatter().string(from: timeMin)))
            query.append(URLQueryItem(name: "timeMax", value: ISO8601DateFormatter().string(from: timeMax)))
        }
        if let pageToken {
            query.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        let encoded = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        return try await client.get(
            url: "\(baseURL)/calendars/\(encoded)/events",
            queryItems: query,
            accountEmail: accountEmail
        )
    }

    func listAllEvents(
        calendarId: String,
        timeMin: Date,
        timeMax: Date,
        accountEmail: String? = nil
    ) async throws -> [GoogleEventDTO] {
        var all: [GoogleEventDTO] = []
        var pageToken: String?
        repeat {
            let response = try await listEvents(
                calendarId: calendarId,
                timeMin: timeMin,
                timeMax: timeMax,
                pageToken: pageToken,
                accountEmail: accountEmail
            )
            all.append(contentsOf: response.items ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return all
    }

    func createEvent(calendarId: String, event: GoogleEventDTO, accountEmail: String? = nil) async throws -> GoogleEventDTO {
        let encoded = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        var urlString = "\(baseURL)/calendars/\(encoded)/events"
        // Append conferenceDataVersion=1 to auto-create Google Meet link
        if event.conferenceData?.createRequest != nil {
            urlString += "?conferenceDataVersion=1"
        }
        return try await client.post(url: urlString, body: event, accountEmail: accountEmail)
    }

    func updateEvent(
        calendarId: String,
        eventId: String,
        event: GoogleEventDTO,
        etag: String? = nil,
        sendUpdates: String? = nil,
        accountEmail: String? = nil
    ) async throws -> GoogleEventDTO {
        let encoded = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        var urlString = "\(baseURL)/calendars/\(encoded)/events/\(eventId)"
        if let sendUpdates {
            urlString += "?sendUpdates=\(sendUpdates)"
        }
        return try await client.patch(
            url: urlString,
            body: event,
            etag: etag,
            accountEmail: accountEmail
        )
    }

    func deleteEvent(calendarId: String, eventId: String, accountEmail: String? = nil) async throws {
        let encoded = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        try await client.delete(url: "\(baseURL)/calendars/\(encoded)/events/\(eventId)", accountEmail: accountEmail)
    }

    func rsvpEvent(
        calendarId: String,
        eventId: String,
        attendees: [GoogleAttendeeDTO],
        accountEmail: String? = nil
    ) async throws -> GoogleEventDTO {
        let encoded = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let body = GoogleAttendeePatchBody(attendees: attendees)
        return try await client.patch(
            url: "\(baseURL)/calendars/\(encoded)/events/\(eventId)",
            body: body,
            accountEmail: accountEmail
        )
    }
}

struct GoogleCalendarListResponse: Codable {
    let kind: String?
    let items: [GoogleCalendarDTO]?
}

struct GoogleCalendarDTO: Codable, Identifiable {
    let id: String
    let summary: String?
    let backgroundColor: String?
    let foregroundColor: String?
    let primary: Bool?
    let accessRole: String?
    let selected: Bool?
}

struct GoogleEventsResponse: Codable {
    let kind: String?
    let items: [GoogleEventDTO]?
    let nextPageToken: String?
    let nextSyncToken: String?
}

struct GoogleEventDTO: Codable, Identifiable {
    var id: String?
    var summary: String?
    var description: String?
    var location: String?
    var start: GoogleEventTime?
    var end: GoogleEventTime?
    var recurrence: [String]?
    var recurringEventId: String?
    var etag: String?
    var colorId: String?
    var updated: Date?
    var status: String?


    // Rich detail fields from Google Calendar API
    var attendees: [GoogleAttendeeDTO]?
    var organizer: GooglePersonDTO?
    var creator: GooglePersonDTO?
    var hangoutLink: String?
    var conferenceData: GoogleConferenceDTO?
    var htmlLink: String?

    static func from(event: CalendarEvent) -> GoogleEventDTO {
        var dto = GoogleEventDTO()
        dto.summary = event.title
        dto.description = event.notes
        dto.location = event.location
        let formatter = ISO8601DateFormatter()
        if event.isAllDay {
            let dateOnly = DateFormatter()
            dateOnly.dateFormat = "yyyy-MM-dd"
            dateOnly.timeZone = TimeZone(identifier: "UTC")
            dto.start = GoogleEventTime(date: dateOnly.string(from: event.startDate))
            dto.end = GoogleEventTime(date: dateOnly.string(from: event.endDate))
        } else {
            dto.start = GoogleEventTime(dateTime: formatter.string(from: event.startDate))
            dto.end = GoogleEventTime(dateTime: formatter.string(from: event.endDate))
        }
        dto.recurrence = event.recurrenceRules
        // Include attendees if present
        if !event.attendees.isEmpty {
            dto.attendees = event.attendees.map { att in
                GoogleAttendeeDTO(email: att.email, displayName: att.displayName, responseStatus: att.responseStatus)
            }
        }
        // Include conference creation request for new events needing Google Meet
        if event.conferenceName == "Google Meet" && event.conferenceURL == "pending-meet-creation" {
            dto.conferenceData = GoogleConferenceDTO(
                createRequest: GoogleConferenceCreateRequest(
                    requestId: UUID().uuidString,
                    conferenceSolutionKey: GoogleConferenceSolutionKey()
                )
            )
        }
        return dto
    }
}

struct GoogleEventTime: Codable {
    var dateTime: String?
    var date: String?
    var timeZone: String?

    var asDate: Date? {
        if let dateTime {
            return ISO8601DateFormatter().date(from: dateTime)
        }
        if let date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.date(from: date)
        }
        return nil
    }

    var isAllDay: Bool {
        date != nil && dateTime == nil
    }
}

// MARK: - Google Calendar Rich Detail DTOs

struct GoogleAttendeeDTO: Codable {
    var email: String?
    var displayName: String?
    var responseStatus: String?  // "accepted", "declined", "tentative", "needsAction"
    var organizer: Bool?
    var `self`: Bool?
    var optional: Bool?
}

struct GooglePersonDTO: Codable {
    var email: String?
    var displayName: String?
    var `self`: Bool?
}

struct GoogleConferenceDTO: Codable {
    var entryPoints: [GoogleEntryPointDTO]?
    var conferenceSolution: GoogleConferenceSolutionDTO?
    var conferenceId: String?
    var createRequest: GoogleConferenceCreateRequest?
}

struct GoogleEntryPointDTO: Codable {
    var entryPointType: String?  // "video", "phone", "sip", "more"
    var uri: String?
    var label: String?
}

struct GoogleConferenceSolutionDTO: Codable {
    var name: String?
    var iconUri: String?
}

struct GoogleConferenceCreateRequest: Codable {
    var requestId: String
    var conferenceSolutionKey: GoogleConferenceSolutionKey?
}

struct GoogleConferenceSolutionKey: Codable {
    var type: String = "hangoutsMeet"
}

struct GoogleAttendeePatchBody: Encodable {
    let attendees: [GoogleAttendeeDTO]
}

import type { CalendarEvent, Calendar, Attendee } from '@/types/calendar'

const BASE = 'https://www.googleapis.com/calendar/v3'

export class GoogleCalendarClient {
  constructor(private accessToken: string) {}

  private headers(): HeadersInit {
    return { Authorization: `Bearer ${this.accessToken}` }
  }

  private async fetchWithRetry(url: string, init?: RequestInit, retries = 3): Promise<Response> {
    for (let i = 0; i < retries; i++) {
      const res = await fetch(url, { ...init, headers: { ...this.headers(), ...init?.headers } })
      if (res.status === 429 || res.status >= 500) {
        await new Promise((r) => setTimeout(r, Math.pow(2, i) * 1000))
        continue
      }
      return res
    }
    return fetch(url, { ...init, headers: { ...this.headers(), ...init?.headers } })
  }

  async listCalendars(): Promise<Calendar[]> {
    const res = await this.fetchWithRetry(`${BASE}/users/me/calendarList`)
    if (!res.ok) throw new Error(`listCalendars: ${res.status}`)
    const data = await res.json()
    return (data.items ?? []).map(mapCalendar)
  }

  async listEvents(calendarId: string, timeMin: string, timeMax: string): Promise<CalendarEvent[]> {
    const params = new URLSearchParams({
      timeMin,
      timeMax,
      singleEvents: 'true',
      orderBy: 'startTime',
      maxResults: '2500',
    })
    const res = await this.fetchWithRetry(
      `${BASE}/calendars/${encodeURIComponent(calendarId)}/events?${params}`
    )
    if (!res.ok) throw new Error(`listEvents: ${res.status}`)
    const data = await res.json()
    return (data.items ?? []).map((e: GoogleEventDTO) => mapEvent(e, calendarId))
  }

  async createEvent(calendarId: string, event: CreateEventPayload): Promise<CalendarEvent> {
    const body = buildEventBody(event)
    const params = event.addMeetLink ? '?conferenceDataVersion=1' : ''
    const res = await this.fetchWithRetry(
      `${BASE}/calendars/${encodeURIComponent(calendarId)}/events${params}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
    )
    if (!res.ok) throw new Error(`createEvent: ${res.status} ${await res.text()}`)
    const data = await res.json()
    return mapEvent(data, calendarId)
  }

  async updateEvent(calendarId: string, eventId: string, event: Partial<CreateEventPayload>, etag?: string): Promise<CalendarEvent> {
    const body = buildEventBody(event as CreateEventPayload)
    const headers: Record<string, string> = { 'Content-Type': 'application/json' }
    if (etag) headers['If-Match'] = etag
    const res = await this.fetchWithRetry(
      `${BASE}/calendars/${encodeURIComponent(calendarId)}/events/${encodeURIComponent(eventId)}`,
      { method: 'PATCH', headers, body: JSON.stringify(body) }
    )
    if (res.status === 412 && etag) {
      // Etag conflict - retry without etag
      return this.updateEvent(calendarId, eventId, event)
    }
    if (!res.ok) throw new Error(`updateEvent: ${res.status}`)
    const data = await res.json()
    return mapEvent(data, calendarId)
  }

  async deleteEvent(calendarId: string, eventId: string): Promise<void> {
    const res = await this.fetchWithRetry(
      `${BASE}/calendars/${encodeURIComponent(calendarId)}/events/${encodeURIComponent(eventId)}`,
      { method: 'DELETE' }
    )
    if (!res.ok && res.status !== 404) throw new Error(`deleteEvent: ${res.status}`)
  }

  async rsvp(calendarId: string, eventId: string, response: 'accepted' | 'declined' | 'tentative', email: string): Promise<void> {
    const res = await this.fetchWithRetry(
      `${BASE}/calendars/${encodeURIComponent(calendarId)}/events/${encodeURIComponent(eventId)}`,
      { method: 'PATCH', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ attendees: [{ email, responseStatus: response }] }) }
    )
    if (!res.ok) throw new Error(`rsvp: ${res.status}`)
  }
}

// Types
export interface CreateEventPayload {
  title: string
  startDate: string
  endDate: string
  isAllDay?: boolean
  location?: string
  notes?: string
  guestEmails?: string[]
  addMeetLink?: boolean
  recurrence?: string[]
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type GoogleEventDTO = any

function mapCalendar(c: { id: string; summary: string; backgroundColor: string; foregroundColor: string; primary?: boolean; accessRole: string }): Calendar {
  return {
    id: c.id,
    summary: c.summary,
    backgroundColor: c.backgroundColor ?? '#4285F4',
    foregroundColor: c.foregroundColor ?? '#FFFFFF',
    primary: c.primary,
    accessRole: c.accessRole,
  }
}

function mapEvent(e: GoogleEventDTO, calendarId: string): CalendarEvent {
  const start = e.start?.dateTime ?? e.start?.date ?? ''
  const end = e.end?.dateTime ?? e.end?.date ?? ''
  const isAllDay = !e.start?.dateTime
  const attendees: Attendee[] = (e.attendees ?? []).map((a: GoogleEventDTO) => ({
    email: a.email,
    displayName: a.displayName,
    responseStatus: a.responseStatus ?? 'needsAction',
    self: a.self,
  }))
  const selfAttendee = attendees.find((a) => a.self)
  return {
    id: e.id,
    calendarId,
    title: e.summary ?? '(No title)',
    startDate: start,
    endDate: end,
    isAllDay,
    location: e.location,
    notes: e.description,
    colorId: e.colorId,
    conferenceURL: e.conferenceData?.entryPoints?.[0]?.uri,
    htmlLink: e.htmlLink,
    etag: e.etag,
    recurrence: e.recurrence,
    recurringEventId: e.recurringEventId,
    attendees,
    isDeclined: selfAttendee?.responseStatus === 'declined',
    organizer: e.organizer,
  }
}

function buildEventBody(event: CreateEventPayload) {
  const body: Record<string, unknown> = { summary: event.title }
  if (event.isAllDay) {
    body.start = { date: event.startDate.split('T')[0] }
    body.end = { date: event.endDate.split('T')[0] }
  } else {
    body.start = { dateTime: event.startDate }
    body.end = { dateTime: event.endDate }
  }
  if (event.location) body.location = event.location
  if (event.notes) body.description = event.notes
  if (event.guestEmails?.length) {
    body.attendees = event.guestEmails.map((email) => ({ email }))
  }
  if (event.addMeetLink) {
    body.conferenceData = {
      createRequest: { requestId: crypto.randomUUID(), conferenceSolutionKey: { type: 'hangoutsMeet' } },
    }
  }
  if (event.recurrence) body.recurrence = event.recurrence
  return body
}

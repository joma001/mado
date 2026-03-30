export interface CalendarEvent {
  id: string
  calendarId: string
  title: string
  startDate: string // ISO8601
  endDate: string
  isAllDay: boolean
  location?: string
  notes?: string
  colorId?: string
  conferenceURL?: string
  htmlLink?: string
  etag?: string
  recurrence?: string[]
  recurringEventId?: string
  attendees: Attendee[]
  isDeclined: boolean
  organizer?: { email: string; displayName?: string; self?: boolean }
}

export interface Attendee {
  email: string
  displayName?: string
  responseStatus: 'needsAction' | 'declined' | 'tentative' | 'accepted'
  self?: boolean
}

export interface Calendar {
  id: string
  summary: string
  backgroundColor: string
  foregroundColor: string
  primary?: boolean
  accessRole: string
}

export interface CalendarPrefs {
  googleCalendarId: string
  isSelected: boolean
  name: string
}

export type CalendarViewMode = 'monthly' | 'weekly' | 'daily'

export interface DayGridCell {
  date: Date
  events: CalendarEvent[]
  isCurrentMonth: boolean
  isToday: boolean
  isWeekend: boolean
}

// Google Calendar API color ID to hex mapping
export const GOOGLE_COLOR_MAP: Record<string, string> = {
  '1': '#7986CB', // Lavender
  '2': '#33B679', // Sage
  '3': '#8E24AA', // Grape
  '4': '#E67C73', // Flamingo
  '5': '#F6BF26', // Banana
  '6': '#F4511E', // Tangerine
  '7': '#039BE5', // Peacock
  '8': '#616161', // Graphite
  '9': '#3F51B5', // Blueberry
  '10': '#0B8043', // Basil
  '11': '#D50000', // Tomato
}

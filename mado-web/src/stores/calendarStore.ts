import { create } from 'zustand'
import type { CalendarEvent, Calendar, CalendarPrefs, CalendarViewMode } from '@/types/calendar'
import { startOfWeek, endOfWeek, startOfMonth, endOfMonth, startOfDay, endOfDay, addDays } from 'date-fns'

interface CalendarState {
  events: CalendarEvent[]
  calendars: Calendar[]
  calendarPrefs: CalendarPrefs[]
  selectedDate: Date
  viewMode: CalendarViewMode
  isLoading: boolean
  error: string | null
  selectedEvent: CalendarEvent | null
  isDetailOpen: boolean

  setSelectedDate: (date: Date) => void
  setViewMode: (mode: CalendarViewMode) => void
  navigateForward: () => void
  navigateBack: () => void
  goToToday: () => void
  fetchCalendars: () => Promise<void>
  fetchEvents: () => Promise<void>
  fetchCalendarPrefs: () => Promise<void>
  getVisibleRange: () => { start: Date; end: Date }
  setSelectedEvent: (event: CalendarEvent | null) => void
  createEvent: (calendarId: string, payload: Partial<CalendarEvent>) => Promise<void>
  updateEvent: (calendarId: string, eventId: string, payload: Partial<CalendarEvent>, etag?: string) => Promise<void>
  deleteEvent: (calendarId: string, eventId: string) => Promise<void>
}

export const useCalendarStore = create<CalendarState>((set, get) => ({
  events: [],
  calendars: [],
  calendarPrefs: [],
  selectedDate: new Date(),
  viewMode: 'weekly',
  isLoading: false,
  error: null,
  selectedEvent: null,
  isDetailOpen: false,

  setSelectedDate: (date) => set({ selectedDate: date }),
  setViewMode: (mode) => { set({ viewMode: mode }); get().fetchEvents() },

  navigateForward: () => {
    const { selectedDate, viewMode } = get()
    const days = viewMode === 'monthly' ? 30 : viewMode === 'weekly' ? 7 : 1
    set({ selectedDate: addDays(selectedDate, days) })
    get().fetchEvents()
  },

  navigateBack: () => {
    const { selectedDate, viewMode } = get()
    const days = viewMode === 'monthly' ? 30 : viewMode === 'weekly' ? 7 : 1
    set({ selectedDate: addDays(selectedDate, -days) })
    get().fetchEvents()
  },

  goToToday: () => { set({ selectedDate: new Date() }); get().fetchEvents() },

  getVisibleRange: () => {
    const { selectedDate, viewMode } = get()
    if (viewMode === 'monthly') {
      const ms = startOfMonth(selectedDate)
      return { start: startOfWeek(ms), end: addDays(endOfMonth(selectedDate), 7) }
    }
    if (viewMode === 'daily') {
      return { start: startOfDay(selectedDate), end: endOfDay(selectedDate) }
    }
    return { start: startOfWeek(selectedDate), end: endOfWeek(selectedDate) }
  },

  fetchCalendars: async () => {
    try {
      const res = await fetch('/api/google/calendar?action=listCalendars')
      if (!res.ok) throw new Error('Failed to fetch calendars')
      const data = await res.json()
      set({ calendars: data })
    } catch (e) {
      set({ error: String(e) })
    }
  },

  fetchEvents: async () => {
    const { getVisibleRange, calendarPrefs, calendars } = get()
    set({ isLoading: true, error: null })
    try {
      const { start, end } = getVisibleRange()
      const selectedIds = calendarPrefs.filter((p) => p.isSelected).map((p) => p.googleCalendarId)
      const calIds = selectedIds.length > 0 ? selectedIds : calendars.map((c) => c.id)

      const allEvents: CalendarEvent[] = []
      await Promise.all(
        calIds.map(async (calId) => {
          const params = new URLSearchParams({
            action: 'listEvents',
            calendarId: calId,
            timeMin: start.toISOString(),
            timeMax: end.toISOString(),
          })
          const res = await fetch(`/api/google/calendar?${params}`)
          if (res.ok) {
            const events = await res.json()
            allEvents.push(...events)
          }
        })
      )
      set({ events: allEvents, isLoading: false })
    } catch (e) {
      set({ error: String(e), isLoading: false })
    }
  },

  fetchCalendarPrefs: async () => {
    try {
      const res = await fetch('/api/firestore?collection=calendarPrefs')
      if (!res.ok) return
      const docs = await res.json()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const prefs: CalendarPrefs[] = (docs ?? []).map((doc: any) => {
        const f = doc.fields ?? {}
        return {
          googleCalendarId: f.googleCalendarId?.stringValue ?? '',
          isSelected: f.isSelected?.booleanValue ?? true,
          name: f.name?.stringValue ?? '',
        }
      })
      set({ calendarPrefs: prefs })
    } catch { /* ignore */ }
  },

  setSelectedEvent: (event) => set({ selectedEvent: event, isDetailOpen: event !== null }),

  createEvent: async (calendarId, payload) => {
    const tempId = `temp-${Date.now()}`
    const optimistic: CalendarEvent = {
      id: tempId,
      calendarId,
      title: payload.title ?? '',
      startDate: payload.startDate ?? new Date().toISOString(),
      endDate: payload.endDate ?? new Date().toISOString(),
      isAllDay: payload.isAllDay ?? false,
      location: payload.location,
      notes: payload.notes,
      attendees: payload.attendees ?? [],
      isDeclined: false,
      ...payload,
    }
    set((s) => ({ events: [...s.events, optimistic] }))
    try {
      const res = await fetch('/api/google/calendar', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'create', calendarId, ...payload }),
      })
      if (!res.ok) throw new Error('Failed to create event')
      const created: CalendarEvent = await res.json()
      set((s) => ({ events: s.events.map((e) => (e.id === tempId ? created : e)) }))
    } catch (e) {
      set((s) => ({ events: s.events.filter((e) => e.id !== tempId), error: String(e) }))
    }
  },

  updateEvent: async (calendarId, eventId, payload, etag) => {
    const prev = get().events.find((e) => e.id === eventId)
    if (prev) {
      set((s) => ({ events: s.events.map((e) => (e.id === eventId ? { ...e, ...payload } : e)) }))
    }
    try {
      const res = await fetch('/api/google/calendar', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'update', calendarId, eventId, etag, ...payload }),
      })
      if (!res.ok) throw new Error('Failed to update event')
      const updated: CalendarEvent = await res.json()
      set((s) => ({ events: s.events.map((e) => (e.id === eventId ? updated : e)) }))
    } catch (e) {
      if (prev) set((s) => ({ events: s.events.map((ev) => (ev.id === eventId ? prev : ev)), error: String(e) }))
    }
  },

  deleteEvent: async (calendarId, eventId) => {
    const prev = get().events.find((e) => e.id === eventId)
    set((s) => ({ events: s.events.filter((e) => e.id !== eventId), isDetailOpen: false, selectedEvent: null }))
    try {
      const res = await fetch('/api/google/calendar', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'delete', calendarId, eventId }),
      })
      if (!res.ok) throw new Error('Failed to delete event')
    } catch (e) {
      if (prev) set((s) => ({ events: [...s.events, prev], error: String(e) }))
    }
  },
}))

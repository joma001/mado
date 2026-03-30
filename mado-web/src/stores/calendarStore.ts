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

  setSelectedDate: (date: Date) => void
  setViewMode: (mode: CalendarViewMode) => void
  navigateForward: () => void
  navigateBack: () => void
  goToToday: () => void
  fetchCalendars: () => Promise<void>
  fetchEvents: () => Promise<void>
  fetchCalendarPrefs: () => Promise<void>
  getVisibleRange: () => { start: Date; end: Date }
}

export const useCalendarStore = create<CalendarState>((set, get) => ({
  events: [],
  calendars: [],
  calendarPrefs: [],
  selectedDate: new Date(),
  viewMode: 'weekly',
  isLoading: false,
  error: null,

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
}))

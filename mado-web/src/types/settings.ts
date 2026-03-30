export interface AppSettings {
  startOfWeek: number // 1=Sunday, 2=Monday, etc.
  use24HourTime: boolean
  showWeekends: boolean
  showWeekNumbers: boolean
  defaultEventDuration: number // minutes
  defaultReminderMinutes: number
  workingHoursStart: number // 0-23
  workingHoursEnd: number // 0-23
  showDeclinedEvents: boolean
  syncIntervalMinutes: number
  gmailSyncEnabled: boolean
  notificationsEnabled: boolean
  morningBriefEnabled: boolean
}

export const DEFAULT_SETTINGS: AppSettings = {
  startOfWeek: 2, // Monday
  use24HourTime: false,
  showWeekends: true,
  showWeekNumbers: false,
  defaultEventDuration: 60,
  defaultReminderMinutes: 10,
  workingHoursStart: 9,
  workingHoursEnd: 18,
  showDeclinedEvents: false,
  syncIntervalMinutes: 5,
  gmailSyncEnabled: true,
  notificationsEnabled: true,
  morningBriefEnabled: true,
}

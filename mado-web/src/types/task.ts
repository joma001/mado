export interface Task {
  id: string
  title: string
  notes?: string
  status: 'needsAction' | 'completed'
  dueDate?: string // RFC3339
  completedDate?: string
  parentTaskId?: string
  position: number
  taskListId: string
  // Firestore metadata
  priority: TaskPriority
  labelIds: string[]
  recurrenceData?: string // base64-encoded JSON
}

export enum TaskPriority {
  None = 0,
  Low = 1,
  Medium = 2,
  High = 3,
}

export interface TaskList {
  id: string
  title: string
}

export interface TaskLabel {
  id: string
  name: string
  colorRaw: LabelColor
  position: number
  updatedAt: string
}

export type LabelColor = 'red' | 'orange' | 'yellow' | 'green' | 'blue' | 'purple' | 'pink' | 'gray'

export const LABEL_COLORS: Record<LabelColor, string> = {
  red: '#FF3B30',
  orange: '#FF9500',
  yellow: '#FFCC00',
  green: '#34C759',
  blue: '#007AFF',
  purple: '#AF52DE',
  pink: '#FF2D55',
  gray: '#8E8E93',
}

export interface RecurrenceRule {
  frequency: 'daily' | 'weekly' | 'monthly' | 'yearly'
  interval: number
  endDate?: number // Apple reference date (seconds since 2001-01-01) — add 978307200 for Unix
}

// Convert Apple reference date to JS Date
export function appleRefDateToDate(seconds: number): Date {
  return new Date((seconds + 978307200) * 1000)
}

// Convert JS Date to Apple reference date
export function dateToAppleRefDate(date: Date): number {
  return date.getTime() / 1000 - 978307200
}

'use client'

import { Calendar, CheckSquare, FileText, Settings } from 'lucide-react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useCalendarStore } from '@/stores/calendarStore'

const NAV_ITEMS = [
  { href: '/calendar', icon: Calendar, label: 'Calendar' },
  { href: '/tasks', icon: CheckSquare, label: 'Tasks' },
  { href: '/notes', icon: FileText, label: 'Notes' },
  { href: '/settings', icon: Settings, label: 'Settings' },
]

export function Sidebar() {
  const pathname = usePathname()
  const calendars = useCalendarStore((s) => s.calendars)
  const calendarPrefs = useCalendarStore((s) => s.calendarPrefs)

  return (
    <aside className="flex w-56 flex-col border-r border-divider bg-surface-secondary max-md:hidden">
      {/* Logo */}
      <div className="flex items-center gap-2 px-4 py-3">
        <span className="text-lg font-bold text-accent">mado</span>
      </div>

      {/* Navigation */}
      <nav className="flex-1 space-y-0.5 px-2 py-2">
        {NAV_ITEMS.map((item) => {
          const isActive = pathname.startsWith(item.href)
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition ${
                isActive
                  ? 'bg-accent-light text-accent'
                  : 'text-text-secondary hover:bg-hover-bg hover:text-text-primary'
              }`}
            >
              <item.icon className="h-4 w-4" />
              {item.label}
            </Link>
          )
        })}
      </nav>

      {/* Calendar List */}
      <div className="border-t border-divider px-4 py-3">
        <p className="mb-2 text-xs font-medium text-text-tertiary">Calendars</p>
        <div className="space-y-1">
          {calendars.map((cal) => {
            const pref = calendarPrefs.find((p) => p.googleCalendarId === cal.id)
            const isSelected = pref?.isSelected ?? true
            return (
              <label key={cal.id} className="flex items-center gap-2 text-xs text-text-secondary">
                <span
                  className="inline-block h-2.5 w-2.5 rounded-sm"
                  style={{ backgroundColor: cal.backgroundColor, opacity: isSelected ? 1 : 0.3 }}
                />
                <span className={isSelected ? '' : 'opacity-50'}>{cal.summary}</span>
              </label>
            )
          })}
        </div>
      </div>
    </aside>
  )
}

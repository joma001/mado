'use client'

import { Calendar, CheckSquare, FileText, Settings } from 'lucide-react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'

const NAV_ITEMS = [
  { href: '/calendar', icon: Calendar, label: 'Calendar' },
  { href: '/tasks', icon: CheckSquare, label: 'Tasks' },
  { href: '/notes', icon: FileText, label: 'Notes' },
  { href: '/settings', icon: Settings, label: 'Settings' },
]

export function MobileNav() {
  const pathname = usePathname()

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 h-14 border-t border-divider bg-surface md:hidden">
      <div className="grid h-full grid-cols-4">
        {NAV_ITEMS.map((item) => {
          const isActive = pathname.startsWith(item.href)
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex flex-col items-center justify-center gap-0.5 text-xs font-medium transition ${
                isActive ? 'text-accent' : 'text-text-tertiary'
              }`}
            >
              <item.icon className="h-5 w-5" />
              <span>{item.label}</span>
            </Link>
          )
        })}
      </div>
    </nav>
  )
}

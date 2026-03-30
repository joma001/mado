'use client'

import { useEffect, useRef } from 'react'
import { useUndoStore } from '@/stores/undoStore'

export function UndoToast() {
  const toastMessage = useUndoStore((s) => s.toastMessage)
  const undo = useUndoStore((s) => s.undo)
  const clearToast = useUndoStore((s) => s.clearToast)
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    if (toastMessage) {
      if (timerRef.current) clearTimeout(timerRef.current)
      timerRef.current = setTimeout(() => {
        clearToast()
      }, 5000)
    }
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current)
    }
  }, [toastMessage, clearToast])

  if (!toastMessage) return null

  return (
    <div
      className="fixed bottom-20 left-1/2 z-50 -translate-x-1/2 animate-slide-up md:bottom-6"
      role="status"
      aria-live="polite"
    >
      <div className="flex items-center gap-3 rounded-lg bg-text-primary px-4 py-3 shadow-lg">
        <span className="text-sm text-surface">{toastMessage}</span>
        <button
          onClick={() => { void undo() }}
          className="text-sm font-semibold text-accent-light hover:opacity-80 transition"
        >
          Undo
        </button>
      </div>
    </div>
  )
}

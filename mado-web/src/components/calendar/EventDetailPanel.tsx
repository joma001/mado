'use client'

import { useState } from 'react'
import { format, parseISO } from 'date-fns'
import type { CalendarEvent } from '@/types/calendar'
import { useCalendarStore } from '@/stores/calendarStore'

function rsvpIcon(status: string) {
  if (status === 'accepted') return <span className="text-green-500 font-bold">✓</span>
  if (status === 'declined') return <span className="text-red-500 font-bold">✕</span>
  if (status === 'tentative') return <span className="text-yellow-500 font-bold">?</span>
  return <span className="text-text-tertiary font-bold">–</span>
}

function conferenceIcon(url: string) {
  if (url.includes('meet.google')) return '📹'
  if (url.includes('zoom.us')) return '📹'
  if (url.includes('teams.microsoft')) return '📹'
  return '🔗'
}

interface DeleteDialogProps {
  isRecurring: boolean
  onConfirm: (scope: 'this' | 'following') => void
  onCancel: () => void
}

function DeleteDialog({ isRecurring, onConfirm, onCancel }: DeleteDialogProps) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="w-80 rounded-xl bg-surface p-5 shadow-xl border border-border">
        <h3 className="text-sm font-semibold text-text-primary mb-2">Delete event?</h3>
        {isRecurring ? (
          <>
            <p className="text-xs text-text-secondary mb-4">This is a recurring event. Which events do you want to delete?</p>
            <div className="flex flex-col gap-2 mb-4">
              <button
                onClick={() => onConfirm('this')}
                className="rounded-md bg-surface-secondary px-4 py-2 text-sm text-text-primary hover:bg-hover-bg transition"
              >
                This event
              </button>
              <button
                onClick={() => onConfirm('following')}
                className="rounded-md bg-surface-secondary px-4 py-2 text-sm text-text-primary hover:bg-hover-bg transition"
              >
                All following events
              </button>
            </div>
          </>
        ) : (
          <p className="text-xs text-text-secondary mb-4">This will permanently delete the event.</p>
        )}
        <button
          onClick={onCancel}
          className="w-full rounded-md bg-surface-secondary px-4 py-2 text-sm text-text-secondary hover:bg-hover-bg transition"
        >
          Cancel
        </button>
      </div>
    </div>
  )
}

export function EventDetailPanel() {
  const { selectedEvent, isDetailOpen, setSelectedEvent, deleteEvent, updateEvent } = useCalendarStore()
  const [showDeleteDialog, setShowDeleteDialog] = useState(false)
  const [isEditingTitle, setIsEditingTitle] = useState(false)
  const [editTitle, setEditTitle] = useState('')
  const [rsvpLoading, setRsvpLoading] = useState(false)

  if (!isDetailOpen || !selectedEvent) return null

  const event = selectedEvent

  const startDate = parseISO(event.startDate)
  const endDate = parseISO(event.endDate)
  const dateStr = event.isAllDay
    ? format(startDate, 'EEEE, MMMM d, yyyy')
    : `${format(startDate, 'EEEE, MMMM d, yyyy')} · ${format(startDate, 'h:mm a')} – ${format(endDate, 'h:mm a')}`

  function handleClose() {
    setSelectedEvent(null)
    setIsEditingTitle(false)
  }

  function handleTitleEdit() {
    setEditTitle(event.title)
    setIsEditingTitle(true)
  }

  async function handleTitleSave() {
    if (editTitle.trim() && editTitle !== event.title) {
      await updateEvent(event.calendarId, event.id, { title: editTitle.trim() }, event.etag)
    }
    setIsEditingTitle(false)
  }

  async function handleRsvp(response: 'accepted' | 'declined' | 'tentative') {
    setRsvpLoading(true)
    const selfEmail = event.attendees.find((a) => a.self)?.email ?? ''
    try {
      await fetch('/api/google/calendar', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'rsvp',
          calendarId: event.calendarId,
          eventId: event.id,
          response,
          email: selfEmail,
        }),
      })
    } finally {
      setRsvpLoading(false)
    }
  }

  async function handleDeleteConfirm(scope: 'this' | 'following') {
    setShowDeleteDialog(false)
    await deleteEvent(event.calendarId, event.id)
    // scope is passed for future use with recurring event API support
    void scope
  }

  const selfAttendee = event.attendees.find((a) => a.self)
  const isOrganizer = event.organizer?.self === true

  return (
    <>
      {showDeleteDialog && (
        <DeleteDialog
          isRecurring={!!(event.recurrence || event.recurringEventId)}
          onConfirm={handleDeleteConfirm}
          onCancel={() => setShowDeleteDialog(false)}
        />
      )}

      {/* Backdrop */}
      <div
        className="fixed inset-0 z-30"
        onClick={handleClose}
      />

      {/* Panel */}
      <div
        className="fixed right-0 top-0 z-40 h-full w-[360px] border-l border-border bg-surface shadow-2xl flex flex-col"
        style={{ transition: 'transform 0.25s ease' }}
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-divider px-4 py-3">
          <span className="text-xs font-medium text-text-tertiary uppercase tracking-wide">Event</span>
          <button
            onClick={handleClose}
            className="flex h-7 w-7 items-center justify-center rounded-full text-text-secondary hover:bg-hover-bg transition text-lg leading-none"
            aria-label="Close"
          >
            ×
          </button>
        </div>

        {/* Scrollable content */}
        <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
          {/* Title */}
          <div>
            {isEditingTitle ? (
              <input
                autoFocus
                value={editTitle}
                onChange={(e) => setEditTitle(e.target.value)}
                onBlur={handleTitleSave}
                onKeyDown={(e) => { if (e.key === 'Enter') handleTitleSave(); if (e.key === 'Escape') setIsEditingTitle(false) }}
                className="w-full rounded-md border border-border bg-surface px-2 py-1 text-lg font-semibold text-text-primary outline-none focus:border-accent"
              />
            ) : (
              <h2
                className="text-lg font-semibold text-text-primary cursor-text hover:bg-hover-bg rounded px-1 -mx-1 py-0.5 transition"
                onClick={handleTitleEdit}
                title="Click to edit"
              >
                {event.title}
              </h2>
            )}
          </div>

          {/* Date/time */}
          <div className="flex items-start gap-2">
            <span className="mt-0.5 text-text-tertiary text-sm">🗓</span>
            <p className="text-sm text-text-secondary">{dateStr}</p>
          </div>

          {/* Location */}
          {event.location && (
            <div className="flex items-start gap-2">
              <span className="mt-0.5 text-text-tertiary text-sm">📍</span>
              <p className="text-sm text-text-secondary">{event.location}</p>
            </div>
          )}

          {/* Conference link */}
          {event.conferenceURL && (
            <div className="flex items-center gap-2">
              <span className="text-text-tertiary text-sm">{conferenceIcon(event.conferenceURL)}</span>
              <a
                href={event.conferenceURL}
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm text-accent hover:underline truncate"
              >
                Join video call
              </a>
            </div>
          )}

          {/* Notes */}
          {event.notes && (
            <div className="flex items-start gap-2">
              <span className="mt-0.5 text-text-tertiary text-sm">📝</span>
              <p className="text-sm text-text-secondary whitespace-pre-wrap">{event.notes}</p>
            </div>
          )}

          {/* Attendees */}
          {event.attendees.length > 0 && (
            <div>
              <p className="text-xs font-medium text-text-tertiary mb-2 uppercase tracking-wide">
                Attendees ({event.attendees.length})
              </p>
              <ul className="space-y-2">
                {event.attendees.map((a) => (
                  <li key={a.email} className="flex items-center gap-2">
                    <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-accent-light text-xs font-semibold text-accent">
                      {(a.displayName ?? a.email)[0].toUpperCase()}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm text-text-primary truncate">{a.displayName ?? a.email}</p>
                      {a.displayName && <p className="text-xs text-text-tertiary truncate">{a.email}</p>}
                    </div>
                    <span className="shrink-0 text-sm" title={a.responseStatus}>
                      {rsvpIcon(a.responseStatus)}
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* RSVP buttons (only for non-organizers who are attendees) */}
          {!isOrganizer && selfAttendee && (
            <div>
              <p className="text-xs font-medium text-text-tertiary mb-2 uppercase tracking-wide">Your response</p>
              <div className="flex gap-2">
                <button
                  disabled={rsvpLoading}
                  onClick={() => handleRsvp('accepted')}
                  className={`flex-1 rounded-md py-1.5 text-sm font-medium transition ${
                    selfAttendee.responseStatus === 'accepted'
                      ? 'bg-green-500 text-white'
                      : 'bg-surface-secondary text-text-primary hover:bg-hover-bg'
                  }`}
                >
                  Accept
                </button>
                <button
                  disabled={rsvpLoading}
                  onClick={() => handleRsvp('tentative')}
                  className={`flex-1 rounded-md py-1.5 text-sm font-medium transition ${
                    selfAttendee.responseStatus === 'tentative'
                      ? 'bg-yellow-400 text-white'
                      : 'bg-surface-secondary text-text-primary hover:bg-hover-bg'
                  }`}
                >
                  Maybe
                </button>
                <button
                  disabled={rsvpLoading}
                  onClick={() => handleRsvp('declined')}
                  className={`flex-1 rounded-md py-1.5 text-sm font-medium transition ${
                    selfAttendee.responseStatus === 'declined'
                      ? 'bg-red-500 text-white'
                      : 'bg-surface-secondary text-text-primary hover:bg-hover-bg'
                  }`}
                >
                  Decline
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Footer actions */}
        <div className="border-t border-divider px-4 py-3 flex gap-2">
          {event.htmlLink && (
            <a
              href={event.htmlLink}
              target="_blank"
              rel="noopener noreferrer"
              className="flex-1 rounded-md bg-surface-secondary px-3 py-2 text-center text-sm font-medium text-text-primary hover:bg-hover-bg transition"
            >
              Open in Google
            </a>
          )}
          <button
            onClick={() => setShowDeleteDialog(true)}
            className="flex-1 rounded-md bg-surface-secondary px-3 py-2 text-sm font-medium text-red-500 hover:bg-red-50 transition"
          >
            Delete
          </button>
        </div>
      </div>
    </>
  )
}

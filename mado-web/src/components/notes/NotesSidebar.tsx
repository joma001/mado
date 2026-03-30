'use client'

import { useState } from 'react'
import { Plus, CalendarDays, Trash2, FileText } from 'lucide-react'
import { formatDistanceToNow } from 'date-fns'
import { useNotesStore } from '@/stores/notesStore'

export function NotesSidebar() {
  const notes = useNotesStore((s) => s.notes)
  const selectedNoteId = useNotesStore((s) => s.selectedNoteId)
  const selectNote = useNotesStore((s) => s.selectNote)
  const createNote = useNotesStore((s) => s.createNote)
  const deleteNote = useNotesStore((s) => s.deleteNote)
  const createDailyNote = useNotesStore((s) => s.createDailyNote)

  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null)

  const handleNewNote = async () => {
    const name = prompt('Note name:')
    if (name?.trim()) {
      await createNote(name.trim())
    }
  }

  const handleDelete = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation()
    if (confirmDeleteId === id) {
      await deleteNote(id)
      setConfirmDeleteId(null)
    } else {
      setConfirmDeleteId(id)
      // Auto-reset confirmation after 3 seconds
      setTimeout(() => setConfirmDeleteId(null), 3000)
    }
  }

  const regularNotes = notes.filter((n) => !n.isFolder)

  return (
    <aside className="flex w-[220px] flex-shrink-0 flex-col border-r border-divider bg-surface-secondary">
      {/* Header */}
      <div className="border-b border-divider px-3 py-3">
        <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-text-tertiary">Notes</p>
        <div className="flex gap-1.5">
          <button
            type="button"
            onClick={handleNewNote}
            title="New Note"
            className="flex flex-1 items-center justify-center gap-1.5 rounded-md bg-accent px-2 py-1.5 text-xs font-medium text-on-accent transition hover:opacity-90"
          >
            <Plus className="h-3.5 w-3.5" />
            New Note
          </button>
          <button
            type="button"
            onClick={createDailyNote}
            title="Create today's daily note"
            className="flex items-center justify-center rounded-md border border-border px-2 py-1.5 text-text-secondary transition hover:bg-hover-bg"
          >
            <CalendarDays className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>

      {/* Notes list */}
      <div className="flex-1 overflow-y-auto py-1">
        {regularNotes.length === 0 ? (
          <div className="px-3 py-6 text-center">
            <p className="text-xs text-text-tertiary">No notes yet</p>
          </div>
        ) : (
          regularNotes.map((note) => {
            const isSelected = note.id === selectedNoteId
            const isConfirming = confirmDeleteId === note.id
            return (
              <div
                key={note.id}
                onClick={() => selectNote(note.id)}
                className={`group relative cursor-pointer px-3 py-2 transition ${
                  isSelected
                    ? 'bg-accent-light'
                    : 'hover:bg-hover-bg'
                }`}
              >
                <div className="flex items-start gap-2">
                  <FileText className={`mt-0.5 h-3.5 w-3.5 flex-shrink-0 ${isSelected ? 'text-accent' : 'text-text-tertiary'}`} />
                  <div className="min-w-0 flex-1">
                    <p
                      className={`truncate text-xs font-medium leading-tight ${
                        isSelected ? 'text-accent' : 'text-text-primary'
                      }`}
                    >
                      {note.displayName}
                    </p>
                    <p className="mt-0.5 text-[10px] text-text-tertiary">
                      {formatDistanceToNow(new Date(note.updatedAt), { addSuffix: true })}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={(e) => handleDelete(note.id, e)}
                    title={isConfirming ? 'Click again to confirm delete' : 'Delete note'}
                    className={`flex-shrink-0 rounded p-0.5 transition ${
                      isConfirming
                        ? 'text-error opacity-100'
                        : 'text-text-tertiary opacity-0 group-hover:opacity-100 hover:text-error'
                    }`}
                  >
                    <Trash2 className="h-3 w-3" />
                  </button>
                </div>
              </div>
            )
          })
        )}
      </div>
    </aside>
  )
}

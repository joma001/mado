'use client'

import { useEffect } from 'react'
import { useNotesStore } from '@/stores/notesStore'
import { NotesSidebar } from '@/components/notes/NotesSidebar'
import { NotesEditor } from '@/components/notes/NotesEditor'

export default function NotesPage() {
  const fetchNotes = useNotesStore((s) => s.fetchNotes)
  const selectedNoteId = useNotesStore((s) => s.selectedNoteId)

  useEffect(() => {
    fetchNotes()
  }, [fetchNotes])

  return (
    <div className="flex h-full overflow-hidden">
      <NotesSidebar />
      {selectedNoteId ? (
        <NotesEditor />
      ) : (
        <div className="flex flex-1 items-center justify-center">
          <div className="text-center">
            <p className="text-sm font-medium text-text-secondary">Select a note to start editing</p>
            <p className="mt-1 text-xs text-text-tertiary">Or create a new note from the sidebar</p>
          </div>
        </div>
      )}
    </div>
  )
}

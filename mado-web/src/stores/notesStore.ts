import { create } from 'zustand'
import { decodeDocument, extractDocId, encodeFields, sanitizeFileName } from '@/lib/firestore/codec'

export interface Note {
  id: string
  fileName: string
  displayName: string
  content: string
  updatedAt: string
  isFolder?: boolean
}

interface NotesState {
  notes: Note[]
  selectedNoteId: string | null
  isLoading: boolean
  fetchNotes: () => Promise<void>
  selectNote: (id: string) => void
  createNote: (displayName: string, content?: string) => Promise<void>
  createFolder: (name: string) => Promise<void>
  updateNoteContent: (id: string, content: string) => void
  saveNote: (id: string) => Promise<void>
  deleteNote: (id: string) => Promise<void>
  createDailyNote: () => Promise<void>
}

// Per-note debounce timers
const saveTimers = new Map<string, ReturnType<typeof setTimeout>>()

export const useNotesStore = create<NotesState>((set, get) => ({
  notes: [],
  selectedNoteId: null,
  isLoading: false,

  fetchNotes: async () => {
    set({ isLoading: true })
    try {
      const res = await fetch('/api/firestore?collection=notes')
      if (!res.ok) return
      const docs = await res.json()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const notes: Note[] = (docs ?? []).map((doc: any) => {
        const decoded = decodeDocument(doc)
        const id = extractDocId(doc.name)
        return {
          id,
          fileName: (decoded.fileName as string) ?? id,
          displayName: (decoded.displayName as string) ?? id,
          content: (decoded.content as string) ?? '',
          updatedAt: (decoded.updatedAt as string) ?? new Date().toISOString(),
          isFolder: (decoded.isFolder as boolean) ?? false,
        }
      })
      notes.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
      set({ notes, isLoading: false })
    } catch {
      set({ isLoading: false })
    }
  },

  selectNote: (id) => set({ selectedNoteId: id }),

  createNote: async (displayName, content = '') => {
    const now = new Date().toISOString()
    const fileName = displayName.endsWith('.md') ? displayName : `${displayName}.md`
    const id = sanitizeFileName(fileName)
    const note: Note = { id, fileName, displayName, content, updatedAt: now }
    set((state) => ({ notes: [note, ...state.notes], selectedNoteId: id }))
    try {
      await fetch('/api/firestore', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'set',
          collection: 'notes',
          docId: id,
          fields: encodeFields({ fileName, displayName, content, updatedAt: now }),
        }),
      })
    } catch { /* ignore */ }
  },

  createFolder: async (name) => {
    const now = new Date().toISOString()
    const id = sanitizeFileName(name)
    const note: Note = { id, fileName: name, displayName: name, content: '', updatedAt: now, isFolder: true }
    set((state) => ({ notes: [note, ...state.notes] }))
    try {
      await fetch('/api/firestore', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'set',
          collection: 'notes',
          docId: id,
          fields: encodeFields({ fileName: name, displayName: name, content: '', updatedAt: now, isFolder: true }),
        }),
      })
    } catch { /* ignore */ }
  },

  updateNoteContent: (id, content) => {
    const now = new Date().toISOString()
    set((state) => ({
      notes: state.notes.map((n) => n.id === id ? { ...n, content, updatedAt: now } : n),
    }))
    // Debounce save
    if (saveTimers.has(id)) clearTimeout(saveTimers.get(id)!)
    const timer = setTimeout(() => {
      saveTimers.delete(id)
      get().saveNote(id)
    }, 500)
    saveTimers.set(id, timer)
  },

  saveNote: async (id) => {
    const note = get().notes.find((n) => n.id === id)
    if (!note) return
    try {
      await fetch('/api/firestore', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'set',
          collection: 'notes',
          docId: id,
          fields: encodeFields({
            fileName: note.fileName,
            displayName: note.displayName,
            content: note.content,
            updatedAt: note.updatedAt,
          }),
        }),
      })
    } catch { /* ignore */ }
  },

  deleteNote: async (id) => {
    set((state) => ({
      notes: state.notes.filter((n) => n.id !== id),
      selectedNoteId: state.selectedNoteId === id ? null : state.selectedNoteId,
    }))
    try {
      await fetch('/api/firestore', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'delete',
          collection: 'notes',
          docId: id,
        }),
      })
    } catch { /* ignore */ }
  },

  createDailyNote: async () => {
    const today = new Date()
    const yyyy = today.getFullYear()
    const mm = String(today.getMonth() + 1).padStart(2, '0')
    const dd = String(today.getDate()).padStart(2, '0')
    const displayName = `${yyyy}-${mm}-${dd}`
    const fileName = `${displayName}.md`
    const id = sanitizeFileName(fileName)
    // If already exists, just select it
    const existing = get().notes.find((n) => n.id === id)
    if (existing) {
      set({ selectedNoteId: id })
      return
    }
    await get().createNote(displayName)
  },
}))

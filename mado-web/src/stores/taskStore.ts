import { create } from 'zustand'
import type { Task, TaskList, TaskLabel, TaskPriority } from '@/types/task'
import { decodeDocument, extractDocId } from '@/lib/firestore/codec'

interface TaskState {
  tasks: Task[]
  taskLists: TaskList[]
  labels: TaskLabel[]
  selectedListId: string | null
  isLoading: boolean

  fetchTaskLists: () => Promise<void>
  fetchTasks: (listId: string) => Promise<void>
  fetchLabels: () => Promise<void>
  fetchTaskMeta: () => Promise<void>
  setSelectedList: (id: string) => void
}

export const useTaskStore = create<TaskState>((set, get) => ({
  tasks: [],
  taskLists: [],
  labels: [],
  selectedListId: null,
  isLoading: false,

  setSelectedList: (id) => { set({ selectedListId: id }); get().fetchTasks(id) },

  fetchTaskLists: async () => {
    try {
      const res = await fetch('/api/google/tasks?action=listTaskLists')
      if (!res.ok) return
      const lists = await res.json()
      set({ taskLists: lists })
      if (!get().selectedListId && lists.length > 0) {
        set({ selectedListId: lists[0].id })
        get().fetchTasks(lists[0].id)
      }
    } catch { /* ignore */ }
  },

  fetchTasks: async (listId) => {
    set({ isLoading: true })
    try {
      const res = await fetch(`/api/google/tasks?action=listTasks&listId=${encodeURIComponent(listId)}`)
      if (!res.ok) return
      const apiTasks = await res.json()
      // Merge with Firestore metadata
      const { tasks: existing } = get()
      const metaMap = new Map(existing.map((t) => [t.id, t]))
      const merged: Task[] = apiTasks.map((t: Omit<Task, 'priority' | 'labelIds' | 'recurrenceData'>) => {
        const meta = metaMap.get(t.id)
        return {
          ...t,
          priority: meta?.priority ?? 0,
          labelIds: meta?.labelIds ?? [],
          recurrenceData: meta?.recurrenceData,
        }
      })
      set({ tasks: merged, isLoading: false })
    } catch {
      set({ isLoading: false })
    }
  },

  fetchLabels: async () => {
    try {
      const res = await fetch('/api/firestore?collection=labels')
      if (!res.ok) return
      const docs = await res.json()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const labels: TaskLabel[] = (docs ?? []).map((doc: any) => {
        const decoded = decodeDocument(doc)
        return {
          id: extractDocId(doc.name),
          name: decoded.name as string,
          colorRaw: decoded.colorRaw as TaskLabel['colorRaw'],
          position: decoded.position as number,
          updatedAt: decoded.updatedAt as string,
        }
      })
      set({ labels: labels.sort((a, b) => a.position - b.position) })
    } catch { /* ignore */ }
  },

  fetchTaskMeta: async () => {
    try {
      const res = await fetch('/api/firestore?collection=taskMeta')
      if (!res.ok) return
      const docs = await res.json()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const metaMap = new Map<string, { priority: TaskPriority; labelIds: string[]; recurrenceData?: string }>()
      for (const doc of docs ?? []) {
        const id = extractDocId(doc.name)
        const decoded = decodeDocument(doc)
        metaMap.set(id, {
          priority: (decoded.priority as number) ?? 0,
          labelIds: (decoded.labelIds as string[]) ?? [],
          recurrenceData: decoded.recurrenceData as string | undefined,
        })
      }
      // Update existing tasks with metadata
      set((state) => ({
        tasks: state.tasks.map((t) => {
          const meta = metaMap.get(t.id)
          if (!meta) return t
          return { ...t, ...meta }
        }),
      }))
    } catch { /* ignore */ }
  },
}))

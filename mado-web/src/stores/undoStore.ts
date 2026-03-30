import { create } from 'zustand'

export interface UndoAction {
  type: 'event_update' | 'event_delete' | 'task_update' | 'task_complete'
  description: string
  undo: () => Promise<void>
  redo: () => Promise<void>
}

interface UndoState {
  undoStack: UndoAction[]
  redoStack: UndoAction[]
  toastMessage: string | null
  pushUndo: (action: UndoAction) => void
  undo: () => Promise<void>
  redo: () => Promise<void>
  clearToast: () => void
}

const MAX_STACK_SIZE = 20

export const useUndoStore = create<UndoState>((set, get) => ({
  undoStack: [],
  redoStack: [],
  toastMessage: null,

  pushUndo: (action) => {
    set((state) => ({
      undoStack: [...state.undoStack, action].slice(-MAX_STACK_SIZE),
      redoStack: [],
      toastMessage: action.description,
    }))
    setTimeout(() => {
      get().clearToast()
    }, 5000)
  },

  undo: async () => {
    const { undoStack } = get()
    if (undoStack.length === 0) return
    const action = undoStack[undoStack.length - 1]
    set((state) => ({
      undoStack: state.undoStack.slice(0, -1),
      redoStack: [...state.redoStack, action],
      toastMessage: null,
    }))
    await action.undo()
  },

  redo: async () => {
    const { redoStack } = get()
    if (redoStack.length === 0) return
    const action = redoStack[redoStack.length - 1]
    set((state) => ({
      redoStack: state.redoStack.slice(0, -1),
      undoStack: [...state.undoStack, action],
      toastMessage: null,
    }))
    await action.redo()
  },

  clearToast: () => set({ toastMessage: null }),
}))

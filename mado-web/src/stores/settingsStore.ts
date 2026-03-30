import { create } from 'zustand'
import type { AppSettings } from '@/types/settings'
import { DEFAULT_SETTINGS } from '@/types/settings'
import { decodeDocument } from '@/lib/firestore/codec'

interface SettingsState {
  settings: AppSettings
  isLoaded: boolean
  fetchSettings: () => Promise<void>
  updateSetting: <K extends keyof AppSettings>(key: K, value: AppSettings[K]) => void
  saveSettings: () => Promise<void>
}

export const useSettingsStore = create<SettingsState>((set, get) => ({
  settings: DEFAULT_SETTINGS,
  isLoaded: false,

  fetchSettings: async () => {
    try {
      const res = await fetch('/api/firestore?collection=settings&docId=preferences')
      if (!res.ok) return
      const doc = await res.json()
      if (!doc?.fields) return
      const decoded = decodeDocument(doc)
      set({
        settings: { ...DEFAULT_SETTINGS, ...decoded } as AppSettings,
        isLoaded: true,
      })
    } catch { /* use defaults */ }
  },

  updateSetting: (key, value) => {
    set((state) => ({
      settings: { ...state.settings, [key]: value },
    }))
  },

  saveSettings: async () => {
    const { settings } = get()
    try {
      await fetch('/api/firestore', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'set',
          collection: 'settings',
          docId: 'preferences',
          fields: { ...settings, updatedAt: new Date() },
        }),
      })
    } catch { /* ignore */ }
  },
}))

'use client'

import { useSettingsStore } from '@/stores/settingsStore'

export default function SettingsPage() {
  const { settings, updateSetting, saveSettings } = useSettingsStore()

  return (
    <div className="mx-auto max-w-2xl overflow-y-auto p-6">
      <h1 className="mb-6 text-xl font-bold text-text-primary">Settings</h1>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold text-text-secondary">Calendar</h2>
        <div className="space-y-3">
          <label className="flex items-center justify-between">
            <span className="text-sm text-text-primary">24-hour time</span>
            <input
              type="checkbox"
              checked={settings.use24HourTime}
              onChange={(e) => { updateSetting('use24HourTime', e.target.checked); saveSettings() }}
              className="accent-accent"
            />
          </label>
          <label className="flex items-center justify-between">
            <span className="text-sm text-text-primary">Show weekends</span>
            <input
              type="checkbox"
              checked={settings.showWeekends}
              onChange={(e) => { updateSetting('showWeekends', e.target.checked); saveSettings() }}
              className="accent-accent"
            />
          </label>
          <label className="flex items-center justify-between">
            <span className="text-sm text-text-primary">Show week numbers</span>
            <input
              type="checkbox"
              checked={settings.showWeekNumbers}
              onChange={(e) => { updateSetting('showWeekNumbers', e.target.checked); saveSettings() }}
              className="accent-accent"
            />
          </label>
          <label className="flex items-center justify-between">
            <span className="text-sm text-text-primary">Show declined events</span>
            <input
              type="checkbox"
              checked={settings.showDeclinedEvents}
              onChange={(e) => { updateSetting('showDeclinedEvents', e.target.checked); saveSettings() }}
              className="accent-accent"
            />
          </label>
          <label className="flex items-center justify-between">
            <span className="text-sm text-text-primary">Working hours start</span>
            <select
              value={settings.workingHoursStart}
              onChange={(e) => { updateSetting('workingHoursStart', Number(e.target.value)); saveSettings() }}
              className="rounded border border-border bg-surface px-2 py-1 text-sm"
            >
              {Array.from({ length: 24 }, (_, i) => (
                <option key={i} value={i}>{i}:00</option>
              ))}
            </select>
          </label>
          <label className="flex items-center justify-between">
            <span className="text-sm text-text-primary">Working hours end</span>
            <select
              value={settings.workingHoursEnd}
              onChange={(e) => { updateSetting('workingHoursEnd', Number(e.target.value)); saveSettings() }}
              className="rounded border border-border bg-surface px-2 py-1 text-sm"
            >
              {Array.from({ length: 24 }, (_, i) => (
                <option key={i} value={i}>{i}:00</option>
              ))}
            </select>
          </label>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold text-text-secondary">Sync</h2>
        <label className="flex items-center justify-between">
          <span className="text-sm text-text-primary">Sync interval (minutes)</span>
          <select
            value={settings.syncIntervalMinutes}
            onChange={(e) => { updateSetting('syncIntervalMinutes', Number(e.target.value)); saveSettings() }}
            className="rounded border border-border bg-surface px-2 py-1 text-sm"
          >
            {[1, 2, 5, 10, 15, 30].map((m) => (
              <option key={m} value={m}>{m}</option>
            ))}
          </select>
        </label>
      </section>
    </div>
  )
}

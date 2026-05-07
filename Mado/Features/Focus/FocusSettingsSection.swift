import SwiftUI

struct FocusSettingsSection: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Section("Pomodoro") {
            Stepper("Work: \(settings.pomodoroWorkDuration) min",
                    value: $settings.pomodoroWorkDuration,
                    in: 5...120, step: 5)

            Stepper("Short break: \(settings.pomodoroShortBreakDuration) min",
                    value: $settings.pomodoroShortBreakDuration,
                    in: 1...30)

            Stepper("Long break: \(settings.pomodoroLongBreakDuration) min",
                    value: $settings.pomodoroLongBreakDuration,
                    in: 1...30)

            Stepper("Long break after \(settings.pomodoroLongBreakInterval) sessions",
                    value: $settings.pomodoroLongBreakInterval,
                    in: 2...8)

            Toggle("Sync sessions to Google Calendar", isOn: $settings.pomodoroSyncToCalendar)

            Toggle("Auto-append to daily note", isOn: $settings.pomodoroAutoAppendNotes)
        }
    }
}

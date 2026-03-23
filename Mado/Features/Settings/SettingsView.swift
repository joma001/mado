import SwiftUI
#if os(macOS)
import KeyboardShortcuts
#endif

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            GeneralSettingsTab(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gear") }

            CalendarSettingsTab(viewModel: viewModel)
                .tabItem { Label("Calendar", systemImage: "calendar.badge.clock") }

            #if os(macOS)
            ShortcutsSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            #endif

            CalendarSelectionView(viewModel: viewModel)
                .tabItem { Label("Calendars", systemImage: "calendar") }
        }
        #if os(macOS)
        .frame(width: 520, height: 560)
        #endif
        .onAppear { viewModel.loadCalendars() }
    }
}

// MARK: - General Settings

private struct GeneralSettingsTab: View {
    var viewModel: SettingsViewModel
    @Bindable private var settings = AppSettings.shared
    private let auth = AuthenticationManager.shared
    private let sync = SyncEngine.shared

    var body: some View {
        Form {
            Section("Accounts") {
                ForEach(auth.accounts) { account in
                    HStack(spacing: MadoTheme.Spacing.sm) {
                        if let url = account.photoURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                accountInitialsView(account)
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        } else {
                            accountInitialsView(account)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: MadoTheme.Spacing.xxs) {
                                Text(account.name)
                                    .font(MadoTheme.Font.bodyMedium)
                                    .foregroundColor(MadoColors.textPrimary)
                                if account.isPrimary {
                                    Text("Primary")
                                        .font(MadoTheme.Font.tiny)
                                        .foregroundColor(MadoColors.accent)
                                        .padding(.horizontal, MadoTheme.Spacing.xxs)
                                        .padding(.vertical, 1)
                                        .background(MadoColors.accentLight)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(account.email)
                                .font(MadoTheme.Font.caption)
                                .foregroundColor(MadoColors.textSecondary)
                        }

                        Spacer()

                        if !account.isPrimary {
                            Button("Set Primary") {
                                viewModel.setPrimaryAccount(account.email)
                            }
                            .buttonStyle(MadoButtonStyle(variant: .secondary))
                        }

                        Button {
                            viewModel.removeAccount(account.email)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundColor(MadoColors.error)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    Task { await viewModel.addAccount() }
                } label: {
                    HStack(spacing: MadoTheme.Spacing.xxs) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(MadoColors.accent)
                        Text("Add Account")
                            .font(MadoTheme.Font.body)
                            .foregroundColor(MadoColors.accent)
                    }
                }
                .buttonStyle(.plain)

                if !auth.accounts.isEmpty {
                    Button("Sign Out All") { viewModel.signOut() }
                        .buttonStyle(MadoButtonStyle(variant: .secondary))
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .font(MadoTheme.Font.body)
            }

            Section("Notifications") {
                Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
                    .font(MadoTheme.Font.body)
                Toggle("Morning brief", isOn: $settings.morningBriefEnabled)
                    .font(MadoTheme.Font.body)

                if !NotificationManager.shared.isAuthorized {
                    HStack {
                        Text("Notifications not permitted")
                            .font(MadoTheme.Font.caption)
                            .foregroundColor(MadoColors.error)
                        Spacer()
                        Button("Grant Access") {
                            Task { await NotificationManager.shared.requestAuthorization() }
                        }
                        .buttonStyle(MadoButtonStyle(variant: .secondary))
                    }
                }

                if settings.notificationsEnabled && !viewModel.calendars.isEmpty {
                    VStack(alignment: .leading, spacing: MadoTheme.Spacing.xs) {
                        Text("Notify for calendars")
                            .font(MadoTheme.Font.captionMedium)
                            .foregroundColor(MadoColors.textSecondary)

                        ForEach(viewModel.calendars, id: \.id) { cal in
                            HStack(spacing: MadoTheme.Spacing.sm) {
                                Circle()
                                    .fill(cal.displayColor)
                                    .frame(width: 8, height: 8)
                                Text(cal.name)
                                    .font(MadoTheme.Font.caption)
                                    .foregroundColor(MadoColors.textPrimary)
                                    .lineLimit(1)
                                if !cal.accountEmail.isEmpty {
                                    Text(cal.accountEmail)
                                        .font(MadoTheme.Font.tiny)
                                        .foregroundColor(MadoColors.textTertiary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { cal.notificationsEnabled },
                                    set: { newVal in
                                        cal.notificationsEnabled = newVal
                                        DataController.shared.save()
                                    }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }

            Section("Display") {
                Picker("Default view", selection: $settings.defaultViewMode) {
                    Text("Month").tag("monthly")
                    Text("Week").tag("weekly")
                    Text("Day").tag("daily")
                }
                .font(MadoTheme.Font.body)

                Picker("Start of week", selection: $settings.startOfWeek) {
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                    Text("Saturday").tag(7)
                }
                .font(MadoTheme.Font.body)

                Picker("Time format", selection: $settings.use24HourTime) {
                    Text("12-hour (1:00 PM)").tag(false)
                    Text("24-hour (13:00)").tag(true)
                }
                .font(MadoTheme.Font.body)

                Toggle("Show weekends", isOn: $settings.showWeekends)
                    .font(MadoTheme.Font.body)

                Toggle("Show week numbers", isOn: $settings.showWeekNumbers)
                    .font(MadoTheme.Font.body)
            }

            Section("Sync") {
                Picker("Sync interval", selection: $settings.syncIntervalMinutes) {
                    Text("1 min").tag(1.0)
                    Text("5 min").tag(5.0)
                    Text("15 min").tag(15.0)
                    Text("30 min").tag(30.0)
                }
                .font(MadoTheme.Font.body)

                Toggle("Gmail starred → Tasks", isOn: $settings.gmailSyncEnabled)
                    .font(MadoTheme.Font.body)
                Text("Starred emails become tasks. Completing a task unstars it.")
                    .font(MadoTheme.Font.caption)
                    .foregroundColor(MadoColors.textTertiary)

                HStack {
                    Text("Status")
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textPrimary)
                    Spacer()
                    Text(sync.status.displayText)
                        .font(MadoTheme.Font.caption)
                        .foregroundColor(MadoColors.textSecondary)
                }

                Button("Sync Now") {
                    Task { await sync.syncAll() }
                }
                .buttonStyle(MadoButtonStyle(variant: .secondary))
                .disabled(sync.status.isSyncing)
            }

        }
        .formStyle(.grouped)
        .padding(MadoTheme.Spacing.md)
    }

    private func accountInitialsView(_ account: Account) -> some View {
        ZStack {
            Circle()
                .fill(MadoColors.accent.opacity(0.15))
                .frame(width: 32, height: 32)
            Text(account.initials)
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(MadoColors.accent)
        }
    }
}

// MARK: - Calendar Settings

private struct CalendarSettingsTab: View {
    var viewModel: SettingsViewModel
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Event Defaults") {
                Picker("Default duration", selection: $settings.defaultEventDuration) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                }
                .font(MadoTheme.Font.body)

                Picker("Default calendar", selection: $settings.defaultCalendarId) {
                    Text("Primary").tag("")
                    ForEach(viewModel.writableCalendars, id: \.id) { cal in
                        HStack(spacing: MadoTheme.Spacing.xs) {
                            Circle().fill(cal.displayColor).frame(width: 8, height: 8)
                            Text(cal.name)
                        }
                        .tag(cal.googleCalendarId)
                    }
                }
                .font(MadoTheme.Font.body)

                Picker("Default reminder", selection: $settings.defaultReminderMinutes) {
                    Text("None").tag(0)
                    Text("5 minutes before").tag(5)
                    Text("10 minutes before").tag(10)
                    Text("15 minutes before").tag(15)
                    Text("30 minutes before").tag(30)
                    Text("1 hour before").tag(60)
                }
                .font(MadoTheme.Font.body)
            }

            Section("Working Hours") {
                Picker("Start", selection: $settings.workingHoursStart) {
                    ForEach(5..<14, id: \.self) { hour in
                        Text(settings.formatHour(hour)).tag(hour)
                    }
                }
                .font(MadoTheme.Font.body)

                Picker("End", selection: $settings.workingHoursEnd) {
                    ForEach(14..<24, id: \.self) { hour in
                        Text(settings.formatHour(hour)).tag(hour)
                    }
                }
                .font(MadoTheme.Font.body)
            }

            Section("Events") {
                Toggle("Show declined events", isOn: $settings.showDeclinedEvents)
                    .font(MadoTheme.Font.body)
            }

            Section("Menu Bar") {
                Picker("Display", selection: $settings.menuBarDisplayMode) {
                    Text("Next event").tag("nextEvent")
                    Text("Time to next event").tag("timeToNext")
                    Text("Icon only").tag("iconOnly")
                }
                .font(MadoTheme.Font.body)

                if !viewModel.calendars.isEmpty {
                    VStack(alignment: .leading, spacing: MadoTheme.Spacing.xs) {
                        Text("Show in menu bar")
                            .font(MadoTheme.Font.captionMedium)
                            .foregroundColor(MadoColors.textSecondary)

                        ForEach(viewModel.calendars, id: \.id) { cal in
                            HStack(spacing: MadoTheme.Spacing.sm) {
                                Circle()
                                    .fill(cal.displayColor)
                                    .frame(width: 8, height: 8)
                                Text(cal.name)
                                    .font(MadoTheme.Font.caption)
                                    .foregroundColor(MadoColors.textPrimary)
                                    .lineLimit(1)
                                if !cal.accountEmail.isEmpty {
                                    Text(cal.accountEmail)
                                        .font(MadoTheme.Font.tiny)
                                        .foregroundColor(MadoColors.textTertiary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { cal.showInMenuBar },
                                    set: { newVal in
                                        cal.showInMenuBar = newVal
                                        DataController.shared.save()
                                    }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(MadoTheme.Spacing.md)
    }
}

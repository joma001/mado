import SwiftUI

struct iOSSettingsTab: View {
    private let authManager = AuthenticationManager.shared
    private let syncEngine = SyncEngine.shared
    private let settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Accounts") {
                    ForEach(authManager.accounts) { account in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(MadoColors.accent.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Text(account.initials)
                                    .font(MadoTheme.Font.captionMedium)
                                    .foregroundColor(MadoColors.accent)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(account.name)
                                        .font(MadoTheme.Font.bodyMedium)
                                    if account.isPrimary {
                                        Text("Primary")
                                            .font(.caption2)
                                            .foregroundColor(MadoColors.accent)
                                            .padding(.horizontal, 4)
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
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Remove", role: .destructive) {
                                authManager.removeAccount(account.email)
                            }
                            if !account.isPrimary {
                                Button("Set Primary") {
                                    authManager.setPrimaryAccount(account.email)
                                }
                                .tint(MadoColors.accent)
                            }
                        }
                    }

                    Button {
                        Task { await authManager.addAccount() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(MadoColors.accent)
                            Text("Add Account")
                                .foregroundColor(MadoColors.accent)
                        }
                    }

                    if !authManager.accounts.isEmpty {
                        Button("Sign Out All", role: .destructive) {
                            authManager.signOut()
                        }
                    }
                }

                // Sync
                Section("Sync") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(syncEngine.status.displayText)
                            .font(MadoTheme.Font.caption)
                            .foregroundColor(MadoColors.textSecondary)
                    }

                    Button("Sync Now") {
                        Task { await syncEngine.syncAll() }
                    }

                    Toggle("Gmail Sync", isOn: Binding(
                        get: { settings.gmailSyncEnabled },
                        set: { settings.gmailSyncEnabled = $0 }
                    ))
                }

                // Calendar
                Section("Calendar") {
                    Toggle("Show Declined Events", isOn: Binding(
                        get: { settings.showDeclinedEvents },
                        set: { settings.showDeclinedEvents = $0 }
                    ))
                }

                // Notifications
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: { settings.notificationsEnabled = $0 }
                    ))
                    Toggle("Morning Brief", isOn: Binding(
                        get: { settings.morningBriefEnabled },
                        set: { settings.morningBriefEnabled = $0 }
                    ))

                    Picker("Event Reminder", selection: Binding(
                        get: { settings.defaultReminderMinutes },
                        set: { settings.defaultReminderMinutes = $0 }
                    )) {
                        Text("None").tag(0)
                        Text("5 min before").tag(5)
                        Text("10 min before").tag(10)
                        Text("15 min before").tag(15)
                        Text("30 min before").tag(30)
                        Text("1 hour before").tag(60)
                    }

                    if !NotificationManager.shared.isAuthorized {
                        Button("Grant Notification Access") {
                            Task { await NotificationManager.shared.requestAuthorization() }
                        }
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(MadoColors.textSecondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

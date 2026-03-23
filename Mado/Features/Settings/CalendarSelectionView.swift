import SwiftUI

struct CalendarSelectionView: View {
    var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: MadoTheme.Spacing.lg) {
            HStack {
                Text("Select which calendars to display")
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textSecondary)

                Spacer()

                Button {
                    Task { await viewModel.fetchRemoteCalendars() }
                } label: {
                    HStack(spacing: MadoTheme.Spacing.xxs) {
                        if viewModel.isLoadingCalendars {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                        Text("Refresh")
                            .font(MadoTheme.Font.caption)
                    }
                }
                .buttonStyle(MadoButtonStyle(variant: .secondary))
                .disabled(viewModel.isLoadingCalendars)
            }

            if viewModel.calendars.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "No calendars",
                    subtitle: "Click Refresh to load your Google calendars",
                    buttonTitle: "Refresh Calendars"
                ) {
                    Task { await viewModel.fetchRemoteCalendars() }
                }
            } else {
                let grouped = Dictionary(grouping: viewModel.calendars) { $0.accountEmail.isEmpty ? "Default" : $0.accountEmail }
                let sortedKeys = grouped.keys.sorted()
                List {
                    ForEach(sortedKeys, id: \.self) { account in
                        if sortedKeys.count > 1 {
                            Section(account) {
                                ForEach(grouped[account] ?? [], id: \.id) { calendar in
                                    CalendarRow(calendar: calendar) {
                                        viewModel.toggleCalendar(calendar)
                                    }
                                }
                            }
                        } else {
                            ForEach(grouped[account] ?? [], id: \.id) { calendar in
                                CalendarRow(calendar: calendar) {
                                    viewModel.toggleCalendar(calendar)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(MadoTheme.Spacing.lg)
        .onAppear {
            viewModel.loadCalendars()
        }
    }
}

// MARK: - Calendar Row

private struct CalendarRow: View {
    let calendar: UserCalendar
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            Toggle("", isOn: Binding(
                get: { calendar.isSelected },
                set: { _ in onToggle() }
            ))
            #if os(macOS)
            .toggleStyle(.checkbox)
            #endif

            Circle()
                .fill(calendar.displayColor)
                .frame(width: 10, height: 10)

            Text(calendar.name)
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textPrimary)

            if calendar.isPrimary {
                Text("Primary")
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(MadoColors.accent)
                    .padding(.horizontal, MadoTheme.Spacing.xs)
                    .padding(.vertical, 1)
                    .background(MadoColors.accentLight)
                    .clipShape(Capsule())
            }

            Spacer()

            Button {
                calendar.notificationsEnabled.toggle()
                DataController.shared.save()
            } label: {
                Image(systemName: calendar.notificationsEnabled ? "bell.fill" : "bell.slash")
                    .font(.system(size: 11))
                    .foregroundColor(calendar.notificationsEnabled ? MadoColors.accent : MadoColors.textTertiary)
            }
            .buttonStyle(.plain)
            .help(calendar.notificationsEnabled ? "Notifications on" : "Notifications off")

            Text(calendar.accessRole)
                .font(MadoTheme.Font.tiny)
                .foregroundColor(MadoColors.textTertiary)
        }
    }
}

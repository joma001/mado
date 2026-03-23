import SwiftUI

struct NotificationPopoverView: View {
    private let manager = NotificationManager.shared
    private let settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().foregroundColor(MadoColors.divider)

            if !settings.notificationsEnabled {
                mutedBanner
            }

            if manager.entries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .frame(width: 320, height: 380)
        .background(MadoColors.surface)
        .task {
            await manager.importDeliveredNotifications()
            manager.markAllRead()
        }
    }

    private var pastEntries: [NotificationEntry] {
        manager.entries.filter { $0.fireDate <= Date() }
    }

    private var upcomingEntries: [NotificationEntry] {
        manager.entries.filter { $0.fireDate > Date() }.sorted { $0.fireDate < $1.fireDate }
    }

    private var header: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            Text("Notifications")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(MadoColors.textPrimary)

            Button {
                settings.notificationsEnabled.toggle()
                if !settings.notificationsEnabled {
                    manager.removeAllNotifications()
                }
            } label: {
                Image(systemName: settings.notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                    .font(.system(size: 11))
                    .foregroundColor(settings.notificationsEnabled ? MadoColors.accent : MadoColors.textTertiary)
            }
            .buttonStyle(.plain)
            .help(settings.notificationsEnabled ? "Mute notifications" : "Unmute notifications")

            Spacer()

            if !pastEntries.isEmpty {
                Button("Mark all read") { manager.markAllRead() }
                    .font(MadoTheme.Font.caption)
                    .foregroundColor(MadoColors.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !pastEntries.isEmpty {
                    ForEach(pastEntries) { entry in
                        notificationRow(entry)
                        Divider().foregroundColor(MadoColors.divider).padding(.leading, 40)
                    }
                }
                if !upcomingEntries.isEmpty {
                    HStack {
                        Text("Upcoming")
                            .font(MadoTheme.Font.captionMedium)
                            .foregroundColor(MadoColors.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, MadoTheme.Spacing.md)
                    .padding(.vertical, MadoTheme.Spacing.xs)
                    .background(MadoColors.surfaceSecondary.opacity(0.5))

                    ForEach(upcomingEntries) { entry in
                        notificationRow(entry, upcoming: true)
                        Divider().foregroundColor(MadoColors.divider).padding(.leading, 40)
                    }
                }
            }
        }
    }

    private func notificationRow(_ entry: NotificationEntry, upcoming: Bool = false) -> some View {
        HStack(alignment: .top, spacing: MadoTheme.Spacing.sm) {
            Image(systemName: iconFor(entry.type))
                .font(.system(size: 12))
                .foregroundColor(colorFor(entry.type))
                .frame(width: 24, height: 24)
                .background(colorFor(entry.type).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(MadoTheme.Font.bodyMedium)
                    .foregroundColor(MadoColors.textPrimary)
                    .lineLimit(1)
                Text(entry.body)
                    .font(MadoTheme.Font.caption)
                    .foregroundColor(MadoColors.textSecondary)
                    .lineLimit(2)
                Text(upcoming ? futureTime(entry.fireDate) : relativeTime(entry.fireDate))
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(upcoming ? MadoColors.accent : MadoColors.textTertiary)
            }

            Spacer()

            if !upcoming && !entry.isRead {
                Circle()
                    .fill(MadoColors.accent)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
        .background(!upcoming && !entry.isRead ? MadoColors.accentLight.opacity(0.3) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if !upcoming { manager.markRead(entry.id) }
        }
    }

    private var mutedBanner: some View {
        HStack(spacing: MadoTheme.Spacing.xs) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 10))
            Text("System notifications muted")
                .font(MadoTheme.Font.tiny)
        }
        .foregroundColor(MadoColors.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(MadoColors.surfaceSecondary.opacity(0.5))
    }

    private var emptyState: some View {
        VStack(spacing: MadoTheme.Spacing.sm) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 28))
                .foregroundColor(MadoColors.textTertiary.opacity(0.5))
            Text("No notifications yet")
                .font(MadoTheme.Font.caption)
                .foregroundColor(MadoColors.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func iconFor(_ type: String) -> String {
        switch type {
        case "event": return "calendar"
        case "task": return "checkmark.circle"
        case "overdue": return "exclamationmark.circle"
        case "brief": return "sun.horizon"
        default: return "bell"
        }
    }

    private func colorFor(_ type: String) -> Color {
        switch type {
        case "event": return MadoColors.accent
        case "task": return MadoColors.success
        case "overdue": return MadoColors.error
        case "brief": return MadoColors.warning
        default: return MadoColors.textSecondary
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        let days = Int(interval / 86400)
        return days == 1 ? "Yesterday" : "\(days)d ago"
    }

    private func futureTime(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        if interval < 60 { return "In less than a minute" }
        if interval < 3600 { return "In \(Int(interval / 60))m" }
        if interval < 86400 { return "In \(Int(interval / 3600))h" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        return fmt.string(from: date)
    }
}

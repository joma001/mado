import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsTab: View {
    var body: some View {
        ScrollView {
            VStack(spacing: MadoTheme.Spacing.lg) {
                shortcutCard(title: "General", icon: "command.square.fill", color: MadoColors.accent) {
                    customizableRow(label: "Show/Hide Command Bar", shortcutName: nil, fallback: ("⌘", "K"))
                    cardDivider
                    recorderRow(label: "Quick Add Task", name: .quickAddTask)
                    cardDivider
                    recorderRow(label: "Show/Hide Menu Bar", name: .togglePopover)
                    cardDivider
                    recorderRow(label: "Show/Hide mado", name: .openApp)
                    cardDivider
                    recorderRow(label: "Join Next Meeting", name: .joinNextMeeting)
                    cardDivider
                    customizableRow(label: "Search", shortcutName: nil, fallback: ("⌘", "F"))
                    cardDivider
                    customizableRow(label: "Notifications", shortcutName: nil, fallback: ("⌘⇧", "B"))
                    cardDivider
                    customizableRow(label: "Today's Note", shortcutName: nil, fallback: ("⌘", "D"))
                }

                shortcutCard(title: "Navigation", icon: "arrow.left.arrow.right", color: Color(hex: "7B68EE")) {
                    readOnlyRow(label: "Inbox", keys: [("⌘", "1")])
                    cardDivider
                    readOnlyRow(label: "Today", keys: [("⌘", "2")])
                    cardDivider
                    readOnlyRow(label: "Notes", keys: [("⌘", "3")])
                    cardDivider
                    readOnlyRow(label: "Notes Panel", keys: [("⌘⇧", "N")])
                    cardDivider
                    readOnlyRow(label: "Monthly View", keys: [("", "M")])
                    cardDivider
                    readOnlyRow(label: "Weekly View", keys: [("", "W")])
                    cardDivider
                    readOnlyRow(label: "Daily View", keys: [("", "D")])
                    cardDivider
                    readOnlyRow(label: "Go to Today", keys: [("", "T")])
                    cardDivider
                    readOnlyRow(label: "Next Period", keys: [("", "J")])
                    cardDivider
                    readOnlyRow(label: "Previous Period", keys: [("", "K")])
                    cardDivider
                    readOnlyRow(label: "Toggle Task Panel", keys: [("", "[")])
                    cardDivider
                    readOnlyRow(label: "Toggle Invite Panel", keys: [("", "]")])
                    cardDivider
                    readOnlyRow(label: "Zoom In", keys: [("⌘", "+")])
                    cardDivider
                    readOnlyRow(label: "Zoom Out", keys: [("⌘", "−")])
                }

                shortcutCard(title: "Tasks", icon: "checkmark.circle.fill", color: MadoColors.success) {
                    readOnlyRow(label: "Navigate Tasks", keys: [("", "↑"), ("", "↓")])
                    cardDivider
                    readOnlyRow(label: "Open Task Detail", keys: [("", "↩")])
                    cardDivider
                    readOnlyRow(label: "Close / Unfocus", keys: [("", "⎋")])
                    cardDivider
                    readOnlyRow(label: "Toggle Complete", keys: [("", "E")])
                    cardDivider
                    readOnlyRow(label: "Delete Task", keys: [("", "⌫")])
                    cardDivider
                    readOnlyRow(label: "High Priority", keys: [("", "1")])
                    cardDivider
                    readOnlyRow(label: "Medium Priority", keys: [("", "2")])
                    cardDivider
                    readOnlyRow(label: "Low Priority", keys: [("", "3")])
                    cardDivider
                    readOnlyRow(label: "Clear Priority", keys: [("", "0")])
                    cardDivider
                    readOnlyRow(label: "Plan Today", keys: [("", "S")])
                    cardDivider
                    readOnlyRow(label: "Clear Date", keys: [("⇧", "S")])
                }

                shortcutCard(title: "Creation in Calendar", icon: "plus.rectangle.on.rectangle", color: MadoColors.warning) {
                    actionRow(label: "Create Event", icon: "calendar.badge.plus", action: "Click on time slot")
                    cardDivider
                    actionRow(label: "Create Time Block", icon: "rectangle.split.3x1", action: "Drag on time grid")
                }
            }
            .padding(MadoTheme.Spacing.lg)
        }
    }

    // MARK: - Card Container

    private func shortcutCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack(spacing: MadoTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MadoColors.textPrimary)
            }
            .padding(.horizontal, MadoTheme.Spacing.md)
            .padding(.vertical, MadoTheme.Spacing.sm + 2)

            // Card content
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, MadoTheme.Spacing.md)
            .padding(.bottom, MadoTheme.Spacing.sm)
        }
        .background(MadoColors.surfaceSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.lg)
                .stroke(MadoColors.border, lineWidth: 1)
        )
    }

    // MARK: - Row Types

    /// A row with KeyboardShortcuts.Recorder (user-customizable)
    private func recorderRow(label: String, name: KeyboardShortcuts.Name) -> some View {
        HStack {
            Text(label)
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textPrimary)
            Spacer()
            KeyboardShortcuts.Recorder(for: name)
                .controlSize(.small)
        }
        .padding(.vertical, MadoTheme.Spacing.xs)
    }

    /// A row with static key badges (non-customizable, shows modifier + key)
    private func customizableRow(label: String, shortcutName: KeyboardShortcuts.Name?, fallback: (String, String)) -> some View {
        HStack {
            Text(label)
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textPrimary)
            Spacer()
            HStack(spacing: MadoTheme.Spacing.xxs) {
                if !fallback.0.isEmpty {
                    keyBadge(fallback.0)
                }
                keyBadge(fallback.1)
            }
        }
        .padding(.vertical, MadoTheme.Spacing.xs)
    }

    /// A row with read-only key badges
    private func readOnlyRow(label: String, keys: [(String, String)]) -> some View {
        HStack {
            Text(label)
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textPrimary)
            Spacer()
            HStack(spacing: MadoTheme.Spacing.xs) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    HStack(spacing: MadoTheme.Spacing.xxs) {
                        if !key.0.isEmpty {
                            keyBadge(key.0)
                        }
                        keyBadge(key.1)
                    }
                }
            }
        }
        .padding(.vertical, MadoTheme.Spacing.xs)
    }

    /// A row describing a mouse action (for calendar creation)
    private func actionRow(label: String, icon: String, action: String) -> some View {
        HStack {
            HStack(spacing: MadoTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(MadoColors.textTertiary)
                    .frame(width: 16)
                Text(label)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textPrimary)
            }
            Spacer()
            Text(action)
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(MadoColors.textSecondary)
                .padding(.horizontal, MadoTheme.Spacing.sm)
                .padding(.vertical, MadoTheme.Spacing.xxs)
                .background(MadoColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                        .stroke(MadoColors.border, lineWidth: 1)
                )
        }
        .padding(.vertical, MadoTheme.Spacing.xs)
    }

    // MARK: - Key Badge

    private func keyBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(MadoColors.textSecondary)
            .frame(minWidth: 24, minHeight: 22)
            .padding(.horizontal, MadoTheme.Spacing.xs)
            .background(MadoColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .stroke(MadoColors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
    }

    // MARK: - Divider

    private var cardDivider: some View {
        Divider().foregroundColor(MadoColors.divider)
    }
}

import SwiftUI

struct MenuBarPopoverView: View {
    private let viewModel = MenuBarViewModel.shared
    @Environment(\.openWindow) private var openWindow

    private let syncEngine = SyncEngine.shared

    private var hasAnyContent: Bool {
        !viewModel.pastEvents.isEmpty ||
        !viewModel.ongoingEvents.isEmpty ||
        !viewModel.upcomingItems.isEmpty ||
        !viewModel.overdueTasks.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasAnyContent {
                contentScrollView
            } else {
                emptyState
            }

            popoverFooter
        }
        .frame(width: MadoTheme.Layout.menuBarPopoverWidth)
        .frame(minHeight: 200, maxHeight: MadoTheme.Layout.menuBarPopoverHeight)
        .background(MadoColors.surface)
        .onAppear { viewModel.load() }
    }

    // MARK: - Content

    private var contentScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !viewModel.pastEvents.isEmpty {
                        sectionHeader("Earlier")
                        ForEach(viewModel.pastEvents, id: \.id) { event in
                            UpcomingEventRow(event: event, viewModel: viewModel)
                                .opacity(0.5)
                        }
                    }

                    Color.clear.frame(height: 0).id("currentAnchor")

                    if !viewModel.ongoingEvents.isEmpty {
                        sectionHeader("Ongoing")
                        ForEach(viewModel.ongoingEvents, id: \.id) { event in
                            OngoingEventRow(event: event, viewModel: viewModel)
                        }
                    }

                    if !viewModel.upcomingItems.isEmpty {
                        sectionHeader("Upcoming")
                        ForEach(viewModel.upcomingItems) { item in
                            switch item {
                            case .event(let event):
                                UpcomingEventRow(event: event, viewModel: viewModel)
                            case .task(let task):
                                UpcomingTaskRow(task: task) {
                                    viewModel.toggleTask(task)
                                }
                            }
                        }
                    }

                    if !viewModel.overdueTasks.isEmpty {
                        sectionHeader("Overdue")
                        ForEach(viewModel.overdueTasks, id: \.id) { task in
                            OverdueTaskRow(task: task, viewModel: viewModel) {
                                viewModel.toggleTask(task)
                            }
                        }
                    }
                }
                .padding(.bottom, MadoTheme.Spacing.xs)
            }
            .onAppear {
                if !viewModel.pastEvents.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        proxy.scrollTo("currentAnchor", anchor: .top)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: MadoTheme.Spacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(MadoColors.textTertiary)
            Text("All clear for today")
                .font(MadoTheme.Font.caption)
                .foregroundColor(MadoColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MadoTheme.Spacing.xxxl)
    }

    // MARK: - Footer

    private var popoverFooter: some View {
        HStack(spacing: MadoTheme.Spacing.xs) {
            if viewModel.nextMeetingURL != nil {
                Button {
                    viewModel.joinNextMeeting()
                } label: {
                    HStack(spacing: MadoTheme.Spacing.xxs) {
                        Text("Hit")
                            .foregroundColor(MadoColors.textTertiary)

                        KeyboardBadge(key: "⌘")
                        KeyboardBadge(key: "J")

                        Text("to join next call")
                            .foregroundColor(MadoColors.textTertiary)
                    }
                    .font(MadoTheme.Font.tiny)
                }
                .buttonStyle(.plain)
            } else {
                Text(syncEngine.status.displayText)
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(MadoColors.textTertiary)
            }

            Spacer()

            if syncEngine.status.isSyncing {
                ProgressView()
                    .scaleEffect(0.5)
            }

            Button {
                NSApp.activate(ignoringOtherApps: true)
                for w in NSApp.windows where w.title == "mado"
                    && !String(describing: type(of: w)).contains("MenuBar")
                    && !String(describing: type(of: w)).contains("StatusBar") {
                    w.makeKeyAndOrderFront(nil)
                    break
                }
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 13))
                    .foregroundColor(MadoColors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Open main window")
        }
        .padding(.horizontal, MadoTheme.Spacing.lg)
        .padding(.vertical, MadoTheme.Spacing.sm)
        .background(MadoColors.surface)
        .overlay(alignment: .top) {
            Divider().foregroundColor(MadoColors.divider)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(MadoTheme.Font.caption)
            .foregroundColor(MadoColors.textTertiary)
            .padding(.horizontal, MadoTheme.Spacing.lg)
            .padding(.top, MadoTheme.Spacing.md)
            .padding(.bottom, MadoTheme.Spacing.xxs)
    }
}

// MARK: - Ongoing Event Row

private struct OngoingEventRow: View {
    let event: CalendarEvent
    let viewModel: MenuBarViewModel

    @State private var isHovered = false

    private var eventColor: Color {
        viewModel.eventColor(for: event)
    }

    var body: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            Text(event.title)
                .font(MadoTheme.Font.bodyMedium)
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Icons
            eventIcons(light: true)

            TimeBadge(
                text: viewModel.timeRemainingText(for: event),
                style: .ongoingLight
            )
        }
        .padding(.horizontal, MadoTheme.Spacing.lg)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.lg)
                .fill(eventColor)
        )
        .padding(.horizontal, MadoTheme.Spacing.sm)
        .padding(.vertical, MadoTheme.Spacing.xxxs)
        .opacity(isHovered ? 0.9 : 1.0)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private func eventIcons(light: Bool) -> some View {
        let iconColor: Color = light ? .white.opacity(0.85) : eventColor
        let iconSize: CGFloat = 11

        if viewModel.hasAttendees(for: event) {
            Image(systemName: "envelope.fill")
                .font(.system(size: iconSize))
                .foregroundColor(iconColor)
        }

        if viewModel.hasVideoLink(for: event) {
            Image(systemName: "video.fill")
                .font(.system(size: iconSize))
                .foregroundColor(iconColor)
        }
    }
}

// MARK: - Upcoming Event Row

private struct UpcomingEventRow: View {
    let event: CalendarEvent
    let viewModel: MenuBarViewModel

    @State private var isHovered = false

    private var eventColor: Color {
        viewModel.eventColor(for: event)
    }

    var body: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(eventColor)
                .frame(width: 3, height: 28)

            Text(event.title)
                .font(MadoTheme.Font.callout)
                .foregroundColor(MadoColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let url = viewModel.meetingURL(for: event) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10))
                        .foregroundColor(eventColor)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }

            if let locationURL = viewModel.locationURL(for: event) {
                Button {
                    NSWorkspace.shared.open(locationURL)
                } label: {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(eventColor)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }

            TimeBadge(
                text: viewModel.upcomingTimeText(for: event),
                style: .tinted(eventColor)
            )
        }
        .padding(.horizontal, MadoTheme.Spacing.lg)
        .padding(.vertical, MadoTheme.Spacing.xs)
        .background(
            isHovered
                ? eventColor.opacity(0.06)
                : eventColor.opacity(0.03)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Upcoming Task Row

private struct UpcomingTaskRow: View {
    let task: MadoTask
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            Button(action: onToggle) {
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundColor(MadoColors.checkboxUnchecked)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(MadoTheme.Font.callout)
                .foregroundColor(MadoColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

            TaskTypeBadge()

            CompactPriorityBadge(priority: task.priority)
        }
        .padding(.horizontal, MadoTheme.Spacing.lg)
        .padding(.vertical, MadoTheme.Spacing.xs)
        .background(isHovered ? MadoColors.hoverBackground : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Overdue Task Row

private struct OverdueTaskRow: View {
    let task: MadoTask
    let viewModel: MenuBarViewModel
    let onToggle: () -> Void

    @State private var isHovered = false

    private let overdueColor = Color(hex: "EB5757") // MadoColors.error

    var body: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            Button(action: onToggle) {
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundColor(overdueColor.opacity(0.5))
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(MadoTheme.Font.callout)
                .foregroundColor(MadoColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

            TaskTypeBadge()

            if let dateText = viewModel.overdueDateText(for: task) {
                Text(dateText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(overdueColor)
                    .padding(.horizontal, MadoTheme.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: MadoTheme.Radius.xs)
                            .fill(overdueColor.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, MadoTheme.Spacing.lg)
        .padding(.vertical, MadoTheme.Spacing.xs)
        .background(
            isHovered
                ? overdueColor.opacity(0.08)
                : overdueColor.opacity(0.04)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Task Type Badge ("T")

private struct TaskTypeBadge: View {
    var body: some View {
        Text("T")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(MadoColors.accent)
            .frame(width: 16, height: 16)
            .background(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.xs)
                    .fill(MadoColors.accent.opacity(0.12))
            )
    }
}

// MARK: - Compact Priority Badge (letter-based: H, M, L)

private struct CompactPriorityBadge: View {
    let priority: TaskPriority

    private var label: String? {
        switch priority {
        case .high: return "1"
        case .medium: return "2"
        case .low: return "3"
        case .none: return nil
        }
    }

    private var color: Color {
        switch priority {
        case .high: return MadoColors.priorityHigh
        case .medium: return MadoColors.priorityMedium
        case .low: return MadoColors.priorityLow
        case .none: return .clear
        }
    }

    var body: some View {
        if let label {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
                .frame(width: 16, height: 16)
                .background(
                    RoundedRectangle(cornerRadius: MadoTheme.Radius.xs)
                        .fill(color.opacity(0.12))
                )
        }
    }
}

// MARK: - Time Badge

private enum TimeBadgeStyle {
    case ongoingLight
    case tinted(Color)
    case neutral
}

private struct TimeBadge: View {
    let text: String
    var style: TimeBadgeStyle = .neutral

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, MadoTheme.Spacing.xs)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.xs)
                    .fill(backgroundColor)
            )
    }

    private var foregroundColor: Color {
        switch style {
        case .ongoingLight:
            return .white
        case .tinted(let color):
            return color
        case .neutral:
            return MadoColors.textSecondary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .ongoingLight:
            return Color.white.opacity(0.2)
        case .tinted(let color):
            return color.opacity(0.1)
        case .neutral:
            return MadoColors.surfaceSecondary
        }
    }
}

// MARK: - Keyboard Badge (for ⌘ J display)

private struct KeyboardBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundColor(MadoColors.textSecondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(MadoColors.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(MadoColors.border, lineWidth: 0.5)
            )
    }
}

import SwiftUI
import Combine

struct PlannerView: View {
    @Bindable var calendarVM: CalendarViewModel
    @Bindable var todoVM: TodoViewModel

    @State private var showCommandBar = false
    @State private var showTaskPanel = true
    @State private var showInvitePanel = false
    @State private var showSearch = false
    @State private var showMemosPanel = false
    @State private var showCompactCalendar = true
    @State private var taskPanelWidth: CGFloat = 500
    @State private var compactCalendarWidth: CGFloat = 300
    #if os(macOS)
    @State private var keyMonitor: Any?
    #endif

    private var pendingInviteCount: Int {
        let now = Date()
        let oneYearAhead = Calendar.current.date(byAdding: .year, value: 1, to: now)!
        let selectedIds = (try? DataController.shared.fetchSelectedCalendarIds()) ?? []
        let events = (try? DataController.shared.fetchEvents(from: now, to: oneYearAhead, calendarIds: selectedIds)) ?? []
        return events.filter { event in
            event.attendees.contains { $0.isSelf && $0.responseStatus == "needsAction" }
        }.count
    }

    var body: some View {
        ZStack {
            HStack(alignment: .top, spacing: 0) {
                if showTaskPanel {
                    TaskPanelView(viewModel: todoVM, calendarVM: calendarVM, showMemos: $showMemosPanel)
                        .frame(width: taskPanelWidth)
                        .transition(.move(edge: .leading))
                    #if os(macOS)
                    DraggableDivider(dimension: $taskPanelWidth, minDimension: 420, maxDimension: 620, invertDrag: false)
                    #else
                    Divider()
                    #endif
                }

                #if os(macOS)
                if showMemosPanel {
                    // Notes mode: NotesView (fills) + compact today calendar (right)
                    memosContentArea
                } else {
                    calendarContentArea
                }
                #else
                calendarContentArea
                #endif
            }
            .clipped()

            if showCommandBar {
                CommandBarView(
                    isPresented: $showCommandBar,
                    calendarVM: calendarVM,
                    todoVM: todoVM
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            if showSearch {
                SearchOverlay(
                    isPresented: $showSearch,
                    calendarVM: calendarVM,
                    todoVM: todoVM
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Hidden keyboard shortcut buttons
            Button("") {
                withAnimation(MadoTheme.Animation.quick) {
                    showCommandBar.toggle()
                }
            }
            .keyboardShortcut("k", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)

            Button("") { withAnimation(MadoTheme.Animation.quick) { calendarVM.zoomIn() } }
                .keyboardShortcut("+", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
            Button("") { withAnimation(MadoTheme.Animation.quick) { calendarVM.zoomIn() } }
                .keyboardShortcut("=", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
            Button("") { withAnimation(MadoTheme.Animation.quick) { calendarVM.zoomOut() } }
                .keyboardShortcut("-", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
            Button("") {
                withAnimation(MadoTheme.Animation.quick) {
                    showSearch.toggle()
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)

            Button("") {
                withAnimation(MadoTheme.Animation.standard) {
                    showMemosPanel.toggle()
                    if showMemosPanel { showInvitePanel = false }
                }
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)

            Button("") { showNotificationPopover.toggle() }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .frame(width: 0, height: 0)
                .opacity(0)

            Button("") {
                withAnimation(MadoTheme.Animation.standard) {
                    showMemosPanel = true
                }
                Task { @MainActor in
                    NotesViewModel.shared.openTodayNote()
                }
            }
            .keyboardShortcut("d", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .animation(MadoTheme.Animation.standard, value: showTaskPanel)
        .animation(MadoTheme.Animation.standard, value: showInvitePanel)
        .animation(MadoTheme.Animation.standard, value: showCompactCalendar)
        .animation(MadoTheme.Animation.quick, value: showCommandBar)
        .animation(MadoTheme.Animation.quick, value: showSearch)
        .onAppear {
            todoVM.loadTasks()
            calendarVM.loadEvents()
            #if os(macOS)
            installKeyMonitor()
            QuickAddTaskWindow.shared.todoVM = todoVM
            QuickAddTaskWindow.shared.calendarVM = calendarVM
            #endif
        }
        #if os(macOS)
        .onDisappear { removeKeyMonitor() }
        #endif
    }

    // MARK: - Calendar Content (normal mode)

    private var calendarContentArea: some View {
        Group {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    CalendarToolbar(viewModel: calendarVM)
                    notificationBellButton
                    inviteToggleButton
                }

                Group {
                    switch calendarVM.viewMode {
                    case .monthly:
                        MonthlyCalendarView(viewModel: calendarVM)
                    case .weekly:
                        WeeklyCalendarView(viewModel: calendarVM, todoVM: todoVM)
                    case .daily:
                        DailyCalendarView(viewModel: calendarVM, todoVM: todoVM)
                    }
                }
                
            }
            .background(MadoColors.surface)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showInvitePanel {
                Divider()
                InvitePanelView(calendarVM: calendarVM)
                    .frame(width: 280)
                    .transition(.move(edge: .trailing))
            }
        }
    }

    // MARK: - Notes Content (notes mode)

    #if os(macOS)
    @State private var isTaskToggleHovered = false
    @State private var isCalendarToggleHovered = false

    private var memosContentArea: some View {
        VStack(spacing: 0) {
            notesToolbar
            Divider().foregroundColor(MadoColors.divider)
            HStack(spacing: 0) {
                NotesView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showCompactCalendar {
                    DraggableDivider(dimension: $compactCalendarWidth, minDimension: 220, maxDimension: 400, invertDrag: true)

                    CompactTodayView(viewModel: calendarVM)
                        .frame(width: compactCalendarWidth)
                }
            }
        }
        .transition(.opacity)
    }

    private var notesToolbar: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(MadoTheme.Animation.standard) { showTaskPanel.toggle() }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(showTaskPanel ? MadoColors.accent : MadoColors.textTertiary)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(showTaskPanel ? MadoColors.accentLight : (isTaskToggleHovered ? MadoColors.surfaceSecondary : Color.clear))
                    )
            }
            .buttonStyle(.plain)
            .onHover { isTaskToggleHovered = $0 }
            .help("Toggle task panel")

            Spacer()

            Button {
                withAnimation(MadoTheme.Animation.standard) { showCompactCalendar.toggle() }
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(showCompactCalendar ? MadoColors.accent : MadoColors.textTertiary)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(showCompactCalendar ? MadoColors.accentLight : (isCalendarToggleHovered ? MadoColors.surfaceSecondary : Color.clear))
                    )
            }
            .buttonStyle(.plain)
            .onHover { isCalendarToggleHovered = $0 }
            .help("Toggle today calendar")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(MadoColors.surface)
    }
    #endif

    // MARK: - Notification Bell

    @State private var showNotificationPopover = false
    @State private var isBellHovered = false
    private let notifManager = NotificationManager.shared

    private var notificationBellButton: some View {
        Button {
            showNotificationPopover.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: notifManager.unreadCount > 0 ? "bell.badge.fill" : "bell.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(notifManager.unreadCount > 0 ? MadoColors.accent : MadoColors.textTertiary)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(showNotificationPopover ? MadoColors.accentLight : (isBellHovered ? MadoColors.surfaceSecondary : Color.clear))
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { isBellHovered = $0 }
        .help("Notifications")
        .popover(isPresented: $showNotificationPopover, arrowEdge: .bottom) {
            NotificationPopoverView()
        }
    }

    // MARK: - Invite Toggle Button

    @State private var isInviteHovered = false
    private var inviteToggleButton: some View {
        Button {
            withAnimation(MadoTheme.Animation.standard) {
                showInvitePanel.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: showInvitePanel ? "envelope.open.fill" : "envelope.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(showInvitePanel ? MadoColors.accent : MadoColors.textTertiary)
                if !showInvitePanel && pendingInviteCount > 0 {
                    Text("\(pendingInviteCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(MadoColors.accent))
                }
            }
            .frame(height: 26)
            .padding(.horizontal, showInvitePanel || pendingInviteCount == 0 ? 0 : 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(showInvitePanel ? MadoColors.accentLight : (isInviteHovered ? MadoColors.surfaceSecondary : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isInviteHovered = $0 }
        .help("Toggle invites panel (])")
        .padding(.trailing, 14)
    }

    // MARK: - Key Monitor

    #if os(macOS)
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection([.command, .option, .control])
            guard mods.isEmpty else { return event }

            if let responder = event.window?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }

            switch event.charactersIgnoringModifiers {
            case "m":
                calendarVM.viewMode = .monthly
                calendarVM.loadEvents()
                return nil
            case "w":
                calendarVM.viewMode = .weekly
                calendarVM.loadEvents()
                return nil
            case "d":
                calendarVM.viewMode = .daily
                calendarVM.loadEvents()
                return nil
            case "t":
                calendarVM.goToToday()
                return nil
            case "j":
                calendarVM.navigateForward()
                return nil
            case "k":
                calendarVM.navigateBack()
                return nil
            case "[":
                withAnimation(MadoTheme.Animation.standard) { showTaskPanel.toggle() }
                return nil
            case "]":
                withAnimation(MadoTheme.Animation.standard) {
                    if showMemosPanel {
                        showCompactCalendar.toggle()
                    } else {
                        showInvitePanel.toggle()
                    }
                }
                return nil
            case "\\":
                withAnimation(MadoTheme.Animation.standard) {
                    showMemosPanel.toggle()
                    if showMemosPanel { showInvitePanel = false }
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    #endif
}

#if os(macOS)
// MARK: - Draggable Divider

private struct DraggableDivider: View {
    @Binding var dimension: CGFloat
    let minDimension: CGFloat
    let maxDimension: CGFloat
    let invertDrag: Bool

    @State private var startDimension: CGFloat = 0
    @State private var isDragging = false
    @State private var isHovered = false

    var body: some View {
        ZStack {
            Color.clear.frame(width: 8)
            Rectangle()
                .fill(isDragging || isHovered ? MadoColors.accent.opacity(0.4) : MadoColors.divider)
                .frame(width: isDragging || isHovered ? 2 : 1)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.resizeLeftRight.push() }
            else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if !isDragging {
                        startDimension = dimension
                        isDragging = true
                    }
                    let delta = invertDrag ? -value.translation.width : value.translation.width
                    dimension = max(minDimension, min(maxDimension, startDimension + delta))
                }
                .onEnded { _ in isDragging = false }
        )
    }
}
#endif

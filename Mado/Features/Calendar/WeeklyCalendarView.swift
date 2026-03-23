import SwiftUI

struct WeeklyCalendarView: View {
    @Bindable var viewModel: CalendarViewModel
    var todoVM: TodoViewModel

    private let calendar = Calendar.current
    private var hourHeight: CGFloat { viewModel.hourHeight }
    private let gutterWidth = MadoTheme.Layout.calendarTimeGutterWidth

    private let gridLineColor = Color.black.opacity(0.06)
    private let halfHourLineColor = Color.black.opacity(0.03)
    private let columnDividerColor = Color.black.opacity(0.06)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ScrollViewReader { proxy in
                        timeGridOverlay
                            .onAppear { proxy.scrollTo(7, anchor: .top) }
                    }
                } header: {
                    VStack(spacing: 0) {
                        weekDayHeader
                        allDaySection
                        Divider().foregroundColor(gridLineColor)
                    }
                    .background(MadoColors.surface)
                }
            }
        }
        .alert("Move event with guests?", isPresented: $viewModel.showMoveGuestAlert) {
            Button("Send update to guests") {
                viewModel.confirmEventMove(sendNotifications: true)
            }
            Button("Don't send") {
                viewModel.confirmEventMove(sendNotifications: false)
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelPendingMove()
            }
        } message: {
            if let event = viewModel.pendingMoveEvent {
                Text("\"\(event.title)\" has \(event.attendees.count) guest\(event.attendees.count == 1 ? "" : "s"). Would you like to send them a notification about this change?")
            }
        }
    }

    // MARK: - Day Header

    private var weekDayHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth)

            ForEach(Array(viewModel.currentWeekDates.enumerated()), id: \.element) { index, date in
                let isToday = calendar.isDateInToday(date)
                VStack(spacing: 4) {
                    Text(shortDay(date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isToday ? MadoColors.accent : MadoColors.textTertiary)

                    Text(dayNumber(date))
                        .font(.system(size: 14, weight: isToday ? .bold : .regular))
                        .foregroundColor(isToday ? .white : MadoColors.textPrimary)
                        .frame(width: 24, height: 24)
                        .background(isToday ? MadoColors.accent : Color.clear)
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(alignment: .leading) {
                    if index > 0 {
                        Rectangle()
                            .fill(columnDividerColor)
                            .frame(width: 1)
                    }
                }
            }
        }
    }

    // MARK: - All Day Events (Pinned)

    @ViewBuilder
    private var allDaySection: some View {
        let hasAllDay = viewModel.currentWeekDates.contains { !viewModel.allDayEvents(for: $0).isEmpty }

        if hasAllDay {
            HStack(spacing: 0) {
                Text("all-day")
                    .font(.system(size: 9))
                    .foregroundColor(MadoColors.textTertiary)
                    .frame(width: gutterWidth, alignment: .trailing)
                    .padding(.trailing, 8)

                ForEach(Array(viewModel.currentWeekDates.enumerated()), id: \.element) { index, date in
                    VStack(spacing: 1) {
                        ForEach(viewModel.allDayEvents(for: date), id: \.id) { event in
                            Text(event.title)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(MadoColors.textPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(viewModel.colorForEvent(event).opacity(0.15))
                                )
                                .overlay(alignment: .leading) {
                                    UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3, bottomTrailingRadius: 0, topTrailingRadius: 0)
                                        .fill(viewModel.colorForEvent(event))
                                        .frame(width: 3)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 1)
                    .overlay(alignment: .leading) {
                        if index > 0 {
                            Rectangle()
                                .fill(columnDividerColor)
                                .frame(width: 1)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .background(MadoColors.surfaceSecondary.opacity(0.3))
        }
    }

    // MARK: - Time Grid

    private var timeGridOverlay: some View {
        HStack(alignment: .top, spacing: 0) {
            timeGutter

            ForEach(viewModel.currentWeekDates, id: \.self) { date in
                dayColumn(for: date)
            }
        }
        .coordinateSpace(name: "weekGrid")
        .background {
            GeometryReader { geo in
                Color.clear
                    .popover(
                        isPresented: Binding(
                            get: { viewModel.editingEvent != nil },
                            set: { if !$0 { viewModel.editingEvent = nil } }
                        ),
                        attachmentAnchor: .rect(.rect(
                            editingEventAnchorRect(totalWidth: geo.size.width)
                        )),
                        arrowEdge: .trailing
                    ) {
                        if let event = viewModel.editingEvent {
                            EventDetailPopover(event: event, viewModel: viewModel)
                        }
                    }
            }
        }
    }

    private var timeGutter: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.dayHours, id: \.self) { hour in
                Text(hourLabel(hour))
                    .font(MadoTheme.Font.timestamp)
                    .foregroundColor(MadoColors.textTertiary)
                    .frame(width: gutterWidth, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, MadoTheme.Spacing.sm)
                    .offset(y: -6)
                    .id(hour)
            }
        }
    }

    private func dayColumn(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let totalHeight = hourHeight * 24
        let layouts = viewModel.columnLayoutForEvents(on: date)
        let isFirstColumn = viewModel.currentWeekDates.first == date

        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(viewModel.dayHours, id: \.self) { hour in
                        slotCell(hour: hour, date: date, isFirstColumn: isFirstColumn)
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .local)
                        .onChanged { value in
                            guard !viewModel.isMovingEvent && !viewModel.isResizingEvent else { return }
                            if !viewModel.isDragCreating {
                                viewModel.beginDragCreation(date: date, startY: value.startLocation.y)
                            }
                            viewModel.updateDragCreation(currentY: value.location.y)
                        }
                        .onEnded { _ in
                            guard !viewModel.isMovingEvent && !viewModel.isResizingEvent else { return }
                            viewModel.finishDragCreation()
                        }
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        viewModel.isHoveringGrid = true
                        viewModel.hoverY = location.y
                        viewModel.hoverColumnDate = date
                    case .ended:
                        viewModel.isHoveringGrid = false
                    }
                }

                if viewModel.isDragCreating && calendar.isDate(viewModel.dragDate, inSameDayAs: date) {
                    RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                        .fill(MadoColors.accent.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                                .strokeBorder(MadoColors.accent.opacity(0.6), lineWidth: 1)
                        )
                        .frame(width: geo.size.width - 4, height: viewModel.dragPreviewHeight)
                        .offset(x: 2, y: viewModel.dragPreviewTopOffset)
                        .allowsHitTesting(false)
                }

                ForEach(layouts) { layout in
                    let colWidth = max((geo.size.width - 4) / CGFloat(layout.totalColumns), 0)
                    let xPos = CGFloat(layout.column) * colWidth + 2
                    let isPast = layout.event.endDate < Date()
                    let isBeingMoved = viewModel.movingEvent?.id == layout.event.id
                    let isBeingResized = viewModel.resizingEvent?.id == layout.event.id
                    let eventH = viewModel.eventHeight(for: layout.event)

                    Button {
                        guard !viewModel.isMovingEvent && !viewModel.isResizingEvent else { return }
                        viewModel.cancelEventCreation()
                        viewModel.editingEvent = layout.event
                    } label: {
                        EventBlockView(
                            event: layout.event,
                            onDelete: { viewModel.deleteEvent(layout.event) },
                            onConvertToTask: { viewModel.createTaskFromEvent(layout.event) },
                            calendarColor: viewModel.colorForEvent(layout.event),
                            isPast: isPast
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: colWidth, height: eventH)
                    .overlay(alignment: .bottom) {
                        BottomResizeCursorArea()
                            .frame(height: min(10, eventH / 3))
                            .allowsHitTesting(false)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 4, coordinateSpace: .named("weekGrid"))
                            .onChanged { value in
                                let eventTop = viewModel.eventTopOffset(for: layout.event)
                                let bottomEdge = eventTop + eventH
                                let nearBottom = value.startLocation.y > bottomEdge - 10

                                if nearBottom && !viewModel.isMovingEvent {
                                    if !viewModel.isResizingEvent {
                                        viewModel.beginEventResize(layout.event, edge: .bottom, startY: value.startLocation.y)
                                    }
                                    viewModel.updateEventResize(currentY: value.location.y)
                                } else if !viewModel.isResizingEvent {
                                    if !viewModel.isMovingEvent {
                                        viewModel.beginEventMove(layout.event, startY: value.startLocation.y)
                                    }
                                    viewModel.updateEventMove(currentY: value.location.y)
                                    let dates = viewModel.currentWeekDates
                                    let columnWidth = geo.size.width
                                    let dayAreaX = value.location.x - gutterWidth
                                    let columnIndex = max(0, min(dates.count - 1, Int(dayAreaX / columnWidth)))
                                    viewModel.updateEventMoveColumn(date: dates[columnIndex])
                                }
                            }
                            .onEnded { _ in
                                if viewModel.isResizingEvent {
                                    viewModel.finishEventResize()
                                } else {
                                    viewModel.finishEventMove()
                                }
                            }
                    )
                    .offset(x: xPos, y: viewModel.eventTopOffset(for: layout.event))
                    .opacity(isBeingMoved || isBeingResized ? 0.3 : 1.0)
                }


                // Ghost preview for moving event
                if let movingEvent = viewModel.movingEvent,
                   calendar.isDate(viewModel.movingColumnDate, inSameDayAs: date) {
                    let movingColor = viewModel.colorForEvent(movingEvent)
                    RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                        .fill(movingColor.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                                .strokeBorder(movingColor.opacity(0.6), lineWidth: 1.5)
                        )
                        .overlay(alignment: .topLeading) {
                            Text(movingEvent.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(MadoColors.textPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.top, 4)
                        }
                        .frame(width: geo.size.width - 4, height: viewModel.eventHeight(for: movingEvent))
                        .offset(x: 2, y: viewModel.movingEventTopOffset)
                        .allowsHitTesting(false)
                }

                if let resizingEvent = viewModel.resizingEvent,
                   calendar.isDate(resizingEvent.startDate, inSameDayAs: date) {
                    let resizeColor = viewModel.colorForEvent(resizingEvent)
                    RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                        .fill(resizeColor.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                                .strokeBorder(resizeColor.opacity(0.6), lineWidth: 1.5)
                        )
                        .overlay(alignment: .topLeading) {
                            Text(resizingEvent.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(MadoColors.textPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.top, 4)
                        }
                        .frame(width: geo.size.width - 4, height: viewModel.resizingEventHeight)
                        .offset(x: 2, y: viewModel.resizingEventTopOffset)
                        .allowsHitTesting(false)
                }

                if isToday {
                    currentTimeIndicator
                        .offset(y: viewModel.currentTimeYOffset)
                }

                if viewModel.isHoveringGrid && !viewModel.isDragCreating && calendar.isDate(viewModel.hoverColumnDate, inSameDayAs: date) {
                    hoverTimeTooltip
                        .offset(x: (geo.size.width - 80) / 2, y: viewModel.hoverSnappedY - 18)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight)
        .background(isToday ? MadoColors.accent.opacity(0.03) : Color.clear)
    }

    private func editingEventAnchorRect(totalWidth: CGFloat) -> CGRect {
        guard let event = viewModel.editingEvent else { return .zero }
        let dates = viewModel.currentWeekDates
        guard let dayIndex = dates.firstIndex(where: {
            calendar.isDate($0, inSameDayAs: event.startDate)
        }) else { return .zero }

        let dayCount = CGFloat(dates.count)
        let dayWidth = dayCount > 0 ? (totalWidth - gutterWidth) / dayCount : 0
        let layouts = viewModel.columnLayoutForEvents(on: dates[dayIndex])
        guard let layout = layouts.first(where: { $0.event.id == event.id }) else { return .zero }

        let colWidth = max((dayWidth - 4) / CGFloat(layout.totalColumns), 0)
        let x = gutterWidth + CGFloat(dayIndex) * dayWidth + CGFloat(layout.column) * colWidth + 2
        let y = viewModel.eventTopOffset(for: event)

        return CGRect(x: x, y: y, width: colWidth, height: viewModel.eventHeight(for: event))
    }

    private func slotCell(hour: Int, date: Date, isFirstColumn: Bool) -> some View {
        let slotDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        return Rectangle()
            .fill(Color.clear)
            .frame(height: hourHeight)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(gridLineColor)
                    .frame(height: 1)
            }
            .overlay {
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(halfHourLineColor)
                        .frame(height: 1)
                    Spacer(minLength: 0)
                        .frame(height: hourHeight / 2)
                }
            }
            .overlay(alignment: .leading) {
                if !isFirstColumn {
                    Rectangle()
                        .fill(columnDividerColor)
                        .frame(width: 1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.beginEventCreation(hour: hour, date: date)
            }
            .popover(
                isPresented: Binding(
                    get: {
                        viewModel.isCreatingEvent &&
                        viewModel.creationSlotHour == hour &&
                        calendar.isDate(viewModel.creationSlotDate, inSameDayAs: date)
                    },
                    set: { if !$0 { viewModel.cancelEventCreation() } }
                )
            ) {
                EventCreatePopover(viewModel: viewModel, todoVM: todoVM)
            }
            .dropDestination(for: TransferableTask.self) { items, _ in
                guard let task = items.first else { return false }
                viewModel.handleTaskDrop(task, at: slotDate)
                return true
            }
    }

    // MARK: - Current Time Indicator

    private var currentTimeIndicator: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(MadoColors.error)
                .frame(width: 8, height: 8)
                .offset(x: -4)

            Rectangle()
                .fill(MadoColors.error)
                .frame(height: 1.5)
        }
    }

    // MARK: - Hover Time Tooltip

    private var hoverTimeTooltip: some View {
        VStack(spacing: 1) {
            Text(viewModel.hoverTimeText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Text(viewModel.hoverTimeDetailText)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.8))
        )
        .transition(.opacity)
    }

    // MARK: - Helpers

    private func hourLabel(_ hour: Int) -> String {
        AppSettings.shared.formatHour(hour)
    }

    private func shortDay(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date).uppercased()
    }

      private func dayNumber(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        return fmt.string(from: date)
    }
}

#if os(macOS)
import AppKit

private struct BottomResizeCursorArea: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeCursorNSView { ResizeCursorNSView() }
    func updateNSView(_ nsView: ResizeCursorNSView, context: Context) {
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

final class ResizeCursorNSView: NSView {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }
}
#endif



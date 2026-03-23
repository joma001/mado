import SwiftUI

struct DailyCalendarView: View {
    @Bindable var viewModel: CalendarViewModel
    var todoVM: TodoViewModel

    private let calendar = Calendar.current
    private var hourHeight: CGFloat { viewModel.hourHeight }
    private let gutterWidth = MadoTheme.Layout.calendarTimeGutterWidth

    private let gridLineColor = Color.black.opacity(0.06)
    private let halfHourLineColor = Color.black.opacity(0.03)

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
                        dayHeader
                        dailyAllDaySection
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

    @ViewBuilder
    private var dailyAllDaySection: some View {
        let allDay = viewModel.allDayEvents(for: viewModel.selectedDate)
        if !allDay.isEmpty {
            allDayBar(events: allDay)
        }
    }

    private var dayHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth)

            let date = viewModel.selectedDate
            let isToday = calendar.isDateInToday(date)

            VStack(spacing: 4) {
                Text(shortDay(date))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isToday ? MadoColors.accent : MadoColors.textTertiary)

                Text(dayNumber(date))
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(isToday ? .white : MadoColors.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(isToday ? MadoColors.accent : Color.clear)
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .padding(.vertical, 8)

            Spacer()
        }
    }

    @ViewBuilder
    private func allDayBar(events: [CalendarEvent]) -> some View {
        HStack(spacing: 0) {
            Text("all-day")
                .font(MadoTheme.Font.tiny)
                .foregroundColor(MadoColors.textTertiary)
                .frame(width: gutterWidth, alignment: .trailing)
                .padding(.trailing, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MadoTheme.Spacing.xs) {
                    ForEach(events, id: \.id) { event in
                        Text(event.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(MadoColors.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(viewModel.colorForEvent(event).opacity(0.15))
                            )
                            .overlay(alignment: .leading) {
                                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 0, topTrailingRadius: 0)
                                    .fill(viewModel.colorForEvent(event))
                                    .frame(width: 3)
                            }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 6)
        .background(MadoColors.surfaceSecondary.opacity(0.3))
    }

    private var timeGridOverlay: some View {
        let date = viewModel.selectedDate
        let isToday = calendar.isDateInToday(date)
        let totalHeight = hourHeight * 24
        let layouts = viewModel.columnLayoutForEvents(on: date)
        return HStack(alignment: .top, spacing: 0) {
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

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(viewModel.dayHours, id: \.self) { hour in
                            dailySlotCell(hour: hour)
                        }
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8, coordinateSpace: .local)
                            .onChanged { value in
                                guard !viewModel.isMovingEvent else { return }
                                if !viewModel.isDragCreating {
                                    viewModel.beginDragCreation(date: date, startY: value.startLocation.y)
                                }
                                viewModel.updateDragCreation(currentY: value.location.y)
                            }
                            .onEnded { _ in
                                guard !viewModel.isMovingEvent else { return }
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
                            .frame(width: geo.size.width - 8, height: viewModel.dragPreviewHeight)
                            .offset(x: 4, y: viewModel.dragPreviewTopOffset)
                            .allowsHitTesting(false)
                    }

                    ForEach(layouts) { layout in
                        let colWidth = max((geo.size.width - 8) / CGFloat(layout.totalColumns), 0)
                        let xPos = CGFloat(layout.column) * colWidth + 4
                        let isPast = layout.event.endDate < Date()
                        let isBeingMoved = viewModel.movingEvent?.id == layout.event.id
                        Button {
                            guard !viewModel.isMovingEvent else { return }
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
                        .frame(width: colWidth, height: viewModel.eventHeight(for: layout.event))
                        .offset(x: xPos, y: viewModel.eventTopOffset(for: layout.event))
                        .opacity(isBeingMoved ? 0.3 : 1.0)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 8, coordinateSpace: .local)
                                .onChanged { value in
                                    if !viewModel.isMovingEvent {
                                        viewModel.beginEventMove(layout.event, startY: value.startLocation.y)
                                    }
                                    viewModel.updateEventMove(currentY: value.location.y)
                                }
                                .onEnded { _ in
                                    viewModel.finishEventMove()
                                }
                        )
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
                            .frame(width: geo.size.width - 8, height: viewModel.eventHeight(for: movingEvent))
                            .offset(x: 4, y: viewModel.movingEventTopOffset)
                            .allowsHitTesting(false)
                    }


                    if isToday {
                        HStack(spacing: 0) {
                            Circle()
                                .fill(MadoColors.error)
                                .frame(width: 8, height: 8)
                                .offset(x: -4)
                            Rectangle()
                                .fill(MadoColors.error)
                                .frame(height: 1.5)
                        }
                        .offset(y: viewModel.currentTimeYOffset)
                    }

                    if viewModel.isHoveringGrid && !viewModel.isDragCreating {
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
                        .offset(x: (geo.size.width - 80) / 2, y: viewModel.hoverSnappedY - 18)
                        .allowsHitTesting(false)
                    }
                }
                .background {
                    Color.clear
                        .popover(
                            isPresented: Binding(
                                get: { viewModel.editingEvent != nil },
                                set: { if !$0 { viewModel.editingEvent = nil } }
                            ),
                            attachmentAnchor: .rect(.rect(
                                dailyEditingAnchorRect(geoWidth: geo.size.width, layouts: layouts)
                            )),
                            arrowEdge: .trailing
                        ) {
                            if let event = viewModel.editingEvent {
                                EventDetailPopover(event: event, viewModel: viewModel)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: totalHeight)
        }
    }

    private func dailyEditingAnchorRect(geoWidth: CGFloat, layouts: [EventColumnInfo]) -> CGRect {
        guard let event = viewModel.editingEvent,
              let layout = layouts.first(where: { $0.event.id == event.id }) else { return .zero }

        let colWidth = max((geoWidth - 8) / CGFloat(layout.totalColumns), 0)
        let x = CGFloat(layout.column) * colWidth + 4
        let y = viewModel.eventTopOffset(for: event)

        return CGRect(x: x, y: y, width: colWidth, height: viewModel.eventHeight(for: event))
    }

    private func dailySlotCell(hour: Int) -> some View {
        let date = viewModel.selectedDate
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
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.beginEventCreation(hour: hour, date: date)
            }
            .popover(
                isPresented: Binding(
                    get: {
                        viewModel.isCreatingEvent &&
                        viewModel.creationSlotHour == hour &&
                        calendar.isDate(viewModel.creationSlotDate, inSameDayAs: viewModel.selectedDate)
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

    private func hourLabel(_ hour: Int) -> String {
        AppSettings.shared.formatHour(hour)
    }

    private func shortDay(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: date).uppercased()
    }

    private func dayNumber(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        return fmt.string(from: date)
    }
}

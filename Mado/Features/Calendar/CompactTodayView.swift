import SwiftUI

/// A narrow, read-only today schedule shown on the right when Notes mode is active.
/// Shows today's date header, all-day events, and a scrollable time grid with events.
struct CompactTodayView: View {
    @Bindable var viewModel: CalendarViewModel

    private let calendar = Calendar.current
    private let gridLineColor = Color.black.opacity(0.06)
    private let halfHourLineColor = Color.black.opacity(0.03)
    private let gutterWidth: CGFloat = 40

    private var today: Date { calendar.startOfDay(for: Date()) }

    var body: some View {
        VStack(spacing: 0) {
            todayHeader
            Divider().foregroundColor(MadoColors.divider)
            compactAllDay
            ScrollView {
                ScrollViewReader { proxy in
                    compactTimeGrid
                        .onAppear { proxy.scrollTo(8, anchor: .top) }
                }
            }
        }
        .background(MadoColors.surface)
    }

    // MARK: - Header

    private var todayHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(dayOfWeek)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(MadoColors.accent)
                Text(dateString)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(MadoColors.textPrimary)
            }
            Spacer()
            Text("Today")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(MadoColors.accent))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - All-Day

    @ViewBuilder
    private var compactAllDay: some View {
        let allDay = viewModel.allDayEvents(for: today)
        if !allDay.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(allDay, id: \.id) { event in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(viewModel.colorForEvent(event))
                            .frame(width: 3, height: 14)
                        Text(event.title)
                            .font(.system(size: 11))
                            .foregroundColor(MadoColors.textPrimary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(MadoColors.surfaceSecondary.opacity(0.3))
            Divider().foregroundColor(gridLineColor)
        }
    }

    // MARK: - Time Grid

    private var compactTimeGrid: some View {
        let layouts = viewModel.columnLayoutForEvents(on: today)
        let hourHeight = viewModel.hourHeight
        let totalHeight = hourHeight * 24

        return ZStack(alignment: .topLeading) {
            // Hour rows
            VStack(spacing: 0) {
                ForEach(viewModel.dayHours, id: \.self) { hour in
                    HStack(spacing: 0) {
                        Text(hourLabel(hour))
                            .font(.system(size: 9))
                            .foregroundColor(MadoColors.textTertiary)
                            .frame(width: gutterWidth, alignment: .trailing)
                            .padding(.trailing, 4)
                            .offset(y: -5)
                        Rectangle()
                            .fill(gridLineColor)
                            .frame(height: 1)
                    }
                    .frame(height: hourHeight)
                    .id(hour)
                }
            }

            // Events
            GeometryReader { geo in
                let eventAreaWidth = geo.size.width - gutterWidth - 4
                ZStack(alignment: .topLeading) {
                    ForEach(layouts) { layout in
                        let colWidth = max(eventAreaWidth / CGFloat(layout.totalColumns), 0)
                        let xPos = gutterWidth + 4 + CGFloat(layout.column) * colWidth
                        let isPast = layout.event.endDate < Date()

                        compactEventBlock(layout.event, isPast: isPast)
                            .frame(width: colWidth - 2, height: viewModel.eventHeight(for: layout.event))
                            .offset(x: xPos, y: viewModel.eventTopOffset(for: layout.event))
                    }

                    // Current time indicator
                    if calendar.isDateInToday(today) {
                        HStack(spacing: 0) {
                            Spacer().frame(width: gutterWidth)
                            Circle()
                                .fill(MadoColors.error)
                                .frame(width: 6, height: 6)
                                .offset(x: -3)
                            Rectangle()
                                .fill(MadoColors.error)
                                .frame(height: 1.5)
                        }
                        .offset(y: viewModel.currentTimeYOffset)
                    }
                }
            }
            .frame(height: totalHeight)
        }
        .frame(height: totalHeight)
    }

    // MARK: - Compact Event Block

    private func compactEventBlock(_ event: CalendarEvent, isPast: Bool) -> some View {
        let color = viewModel.colorForEvent(event)
        return VStack(alignment: .leading, spacing: 1) {
            Text(event.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(event.isDeclined ? MadoColors.textTertiary : (isPast ? color.opacity(0.6) : MadoColors.textPrimary))
                .strikethrough(event.isDeclined, color: MadoColors.textTertiary)
                .lineLimit(2)
            Text(timeRange(event))
                .font(.system(size: 8))
                .foregroundColor(event.isDeclined ? MadoColors.textPlaceholder : MadoColors.textTertiary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(event.isPendingInvite
                    ? Color.clear
                    : event.isDeclined
                        ? color.opacity(isPast ? 0.03 : 0.06)
                        : color.opacity(isPast ? 0.10 : 0.22))
        )
        .overlay(
            (!event.isPendingInvite && !event.isDeclined)
                ? RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: 1)
                : nil
        )
        .overlay(
            event.isPendingInvite ? RoundedRectangle(cornerRadius: 4)
                .stroke(color.opacity(isPast ? 0.3 : 0.5), lineWidth: 1.5) : nil
        )
        .overlay(alignment: .leading) {
            if event.isPendingInvite {
                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 0, topTrailingRadius: 0)
                    .stroke(color.opacity(isPast ? 0.4 : 0.7), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: 3)
            } else {
                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 0, topTrailingRadius: 0)
                    .fill(color.opacity(event.isDeclined ? (isPast ? 0.15 : 0.3) : (isPast ? 0.3 : 0.8)))
                    .frame(width: 3)
            }
        }
        .opacity(event.isDeclined ? (isPast ? 0.4 : 0.55) : 1.0)
    }

    // MARK: - Helpers

    private func hourLabel(_ hour: Int) -> String {
        AppSettings.shared.formatHour(hour)
    }

    private func timeRange(_ event: CalendarEvent) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    private var dayOfWeek: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: today).uppercased()
    }

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d"
        return fmt.string(from: today)
    }
}

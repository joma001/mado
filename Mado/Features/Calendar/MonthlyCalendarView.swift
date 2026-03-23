import SwiftUI

struct MonthlyCalendarView: View {
    @Bindable var viewModel: CalendarViewModel

    private let cal = Calendar.current
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 0) {
            dayOfWeekHeader

            let grid = viewModel.currentMonthGrid
            ForEach(Array(grid.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { date in
                        MonthDayCellView(date: date, viewModel: viewModel)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .background(MadoColors.surface)
    }

    private var dayOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(dayLabels, id: \.self) { label in
                Text(label)
                    .font(MadoTheme.Font.captionMedium)
                    .foregroundColor(MadoColors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, MadoTheme.Spacing.xs)
        .background(MadoColors.surfaceSecondary)
        .overlay(alignment: .bottom) {
            Divider().foregroundColor(MadoColors.divider)
        }
    }
}

private struct MonthDayCellView: View {
    let date: Date
    @Bindable var viewModel: CalendarViewModel
    @State private var isHovered = false

    private let cal = Calendar.current

    var body: some View {
        let isToday = cal.isDateInToday(date)
        let inMonth = viewModel.isInCurrentMonth(date)
        let dayEvents = viewModel.eventsForDate(date)
        let displayCount = min(dayEvents.count, 2)

        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundColor(isToday ? .white : (inMonth ? MadoColors.textPrimary : MadoColors.textTertiary))
                    .frame(width: 22, height: 22)
                    .background(isToday ? MadoColors.accent : Color.clear)
                    .clipShape(Circle())
                Spacer()
            }
            .padding(.leading, 4)
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 1) {
                ForEach(0..<displayCount, id: \.self) { i in
                    Text(dayEvents[i].title)
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(MadoColors.calendarDefault.opacity(0.8))
                        )
                }
                if dayEvents.count > 2 {
                    Text("+\(dayEvents.count - 2) more")
                        .font(.system(size: 9))
                        .foregroundColor(MadoColors.textTertiary)
                        .padding(.horizontal, 3)
                }
            }
            .padding(.horizontal, 2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            isHovered
                ? MadoColors.hoverBackground
                : (inMonth ? MadoColors.surface : MadoColors.surfaceSecondary.opacity(0.5))
        )
        .overlay(
            Rectangle()
                .stroke(MadoColors.divider, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { viewModel.selectDate(date) }
        .dropDestination(for: TransferableTask.self) { items, _ in
            guard let task = items.first else { return false }
            let dropDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
            viewModel.handleTaskDrop(task, at: dropDate)
            return true
        }
    }
}

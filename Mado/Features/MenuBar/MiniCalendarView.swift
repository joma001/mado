import SwiftUI

struct MiniCalendarView: View {
    let viewModel: MenuBarViewModel

    private let cal = Calendar.current
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        if viewModel.isMiniCalendarExpanded {
            expandedView
        }
    }

    private var expandedView: some View {
        VStack(spacing: 0) {
            header
            dayOfWeekHeader
            calendarGrid
            Divider().foregroundColor(MadoColors.divider)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: MadoTheme.Spacing.xs) {
            Text(viewModel.miniCalendarHeaderTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(MadoColors.textPrimary)

            Spacer()

            Button { viewModel.goToToday() } label: {
                Text("Today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(MadoColors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(MadoColors.accentLight.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)

            Button { viewModel.navigateMiniCalendarBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(MadoColors.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)

            Button { viewModel.navigateMiniCalendarForward() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(MadoColors.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MadoTheme.Spacing.lg)
        .padding(.top, MadoTheme.Spacing.sm)
        .padding(.bottom, MadoTheme.Spacing.xxs)
    }

    // MARK: - Day of Week Header

    private var dayOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(dayLabels.indices, id: \.self) { i in
                Text(dayLabels[i])
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(MadoColors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, MadoTheme.Spacing.lg)
        .padding(.vertical, 2)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let grid = viewModel.miniCalendarGrid
        return VStack(spacing: 0) {
            ForEach(Array(grid.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { date in
                        MiniDayCellView(
                            date: date,
                            viewModel: viewModel
                        )
                    }
                }
            }
        }
        .padding(.horizontal, MadoTheme.Spacing.sm)
        .padding(.bottom, MadoTheme.Spacing.xs)
    }
}

// MARK: - Mini Day Cell

private struct MiniDayCellView: View {
    let date: Date
    let viewModel: MenuBarViewModel

    private let cal = Calendar.current

    var body: some View {
        let isToday = cal.isDateInToday(date)
        let inMonth = viewModel.isInSelectedMonth(date)
        let isSelected = viewModel.miniCalendarSelectedDate.map { cal.isDate($0, inSameDayAs: date) } ?? false
        let dotColors = viewModel.miniCalendarCalendarColors(date)

        Button {
            viewModel.selectMiniCalendarDate(date)
        } label: {
            VStack(spacing: 1) {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                    .foregroundColor(dayTextColor(isToday: isToday, inMonth: inMonth, isSelected: isSelected))
                    .frame(width: 24, height: 24)
                    .background(dayBackground(isToday: isToday, isSelected: isSelected))
                    .clipShape(Circle())

                // Event dots
                HStack(spacing: 2) {
                    if dotColors.isEmpty {
                        Circle().fill(Color.clear).frame(width: 4, height: 4)
                    } else {
                        ForEach(Array(dotColors.enumerated()), id: \.offset) { _, color in
                            Circle().fill(color).frame(width: 4, height: 4)
                        }
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 1)
        }
        .buttonStyle(.plain)
    }

    private func dayTextColor(isToday: Bool, inMonth: Bool, isSelected: Bool) -> Color {
        if isToday || isSelected { return .white }
        if !inMonth { return MadoColors.textTertiary.opacity(0.5) }
        return MadoColors.textPrimary
    }

    private func dayBackground(isToday: Bool, isSelected: Bool) -> Color {
        if isToday { return MadoColors.accent }
        if isSelected { return MadoColors.accent.opacity(0.6) }
        return .clear
    }
}

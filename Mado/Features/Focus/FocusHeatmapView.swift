import SwiftUI

struct FocusHeatmapView: View {
    private let calendar = Calendar.current
    @State private var weekData: [(date: Date, minutes: Int)] = []

    private var maxMinutes: Int {
        max(1, weekData.map(\.minutes).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MadoTheme.Spacing.md) {
            Text("This Week")
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(MadoColors.textTertiary)

            HStack(spacing: MadoTheme.Spacing.xs) {
                ForEach(weekData, id: \.date) { item in
                    let intensity = Double(item.minutes) / Double(maxMinutes)
                    let isToday = calendar.isDateInToday(item.date)

                    VStack(spacing: MadoTheme.Spacing.xxxs) {
                        RoundedRectangle(cornerRadius: MadoTheme.Radius.xs)
                            .fill(item.minutes > 0
                                  ? MadoColors.accent.opacity(0.2 + intensity * 0.8)
                                  : MadoColors.surfaceTertiary)
                            .frame(height: 32)
                            .overlay {
                                if item.minutes > 0 {
                                    Text("\(item.minutes)")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(intensity > 0.5 ? MadoColors.onAccent : MadoColors.accent)
                                }
                            }

                        Text(dayLabel(item.date))
                            .font(.system(size: 9, weight: isToday ? .bold : .regular))
                            .foregroundColor(isToday ? MadoColors.accent : MadoColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { loadWeekData() }
    }

    private func loadWeekData() {
        let today = Date()
        let dc = DataController.shared
        weekData = (0..<7).compactMap { offset -> (Date, Int)? in
            guard let date = calendar.date(byAdding: .day, value: -6 + offset, to: calendar.startOfDay(for: today)) else { return nil }
            let sessions = (try? dc.fetchFocusSessions(for: date)) ?? []
            let minutes = sessions.reduce(0) { $0 + max(1, $1.durationSeconds / 60) }
            return (date, minutes)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(2))
    }
}

import SwiftUI

struct FocusStatsView: View {
    @State private var todaySessions: [FocusSession] = []

    private var totalMinutes: Int {
        todaySessions.reduce(0) { $0 + max(1, $1.durationSeconds / 60) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MadoTheme.Spacing.lg) {
            HStack {
                Text("Focus Summary")
                    .font(MadoTheme.Font.headline)
                    .foregroundColor(MadoColors.textPrimary)
                Spacer()
                Text("Today")
                    .font(MadoTheme.Font.caption)
                    .foregroundColor(MadoColors.textTertiary)
            }

            HStack(spacing: MadoTheme.Spacing.md) {
                statCard(value: "\(todaySessions.count)", label: "Sessions", icon: "timer")
                statCard(value: "\(totalMinutes)m", label: "Focus time", icon: "clock")
            }

            if !todaySessions.isEmpty {
                VStack(alignment: .leading, spacing: MadoTheme.Spacing.xs) {
                    Text("Sessions")
                        .font(MadoTheme.Font.captionMedium)
                        .foregroundColor(MadoColors.textTertiary)

                    ForEach(todaySessions, id: \.id) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .padding(MadoTheme.Spacing.lg)
        .onAppear { loadSessions() }
    }

    private func loadSessions() {
        todaySessions = (try? DataController.shared.fetchFocusSessions(for: Date())) ?? []
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: MadoTheme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(MadoColors.accent)
            Text(value)
                .font(MadoTheme.Font.title)
                .foregroundColor(MadoColors.textPrimary)
            Text(label)
                .font(MadoTheme.Font.tiny)
                .foregroundColor(MadoColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MadoTheme.Spacing.md)
        .background(MadoColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.lg))
    }

    private func sessionRow(_ session: FocusSession) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: session.startTime)
        let end = formatter.string(from: session.endTime ?? session.startTime)
        let minutes = max(1, session.durationSeconds / 60)

        return HStack {
            Circle()
                .fill(MadoColors.accent)
                .frame(width: 6, height: 6)

            Text("\(start)–\(end)")
                .font(MadoTheme.Font.timestamp)
                .foregroundColor(MadoColors.textSecondary)

            Text("\(minutes)m")
                .font(MadoTheme.Font.caption)
                .foregroundColor(MadoColors.textTertiary)

            Spacer()

            if let note = session.note, !note.isEmpty {
                Image(systemName: "note.text")
                    .font(.system(size: 10))
                    .foregroundColor(MadoColors.textTertiary)
            }
        }
        .padding(.vertical, MadoTheme.Spacing.xxxs)
    }
}

import SwiftUI

struct FocusBlockView: View {
    let session: FocusSession
    let hourHeight: CGFloat
    var taskTitle: String?

    @State private var isHovered = false

    var topOffset: CGFloat {
        let cal = Calendar.current
        let hour = CGFloat(cal.component(.hour, from: session.startTime))
        let minute = CGFloat(cal.component(.minute, from: session.startTime))
        return (hour + minute / 60.0) * hourHeight
    }

    var blockHeight: CGFloat {
        let minutes = CGFloat(session.durationSeconds) / 60.0
        let height = (minutes / 60.0) * hourHeight
        return max(height, MadoTheme.Layout.eventBlockMinHeight)
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = AppSettings.shared.use24HourTime ? "HH:mm" : "h:mm a"
        let start = formatter.string(from: session.startTime)
        let end = formatter.string(from: session.endTime ?? session.startTime)
        return "\(start) \u{2013} \(end)"
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: MadoTheme.Spacing.xxxs) {
                        Image(systemName: "timer")
                            .font(.system(size: 9, weight: .medium))
                        Text(taskTitle ?? "Focus")
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(MadoColors.accent)

                    if geo.size.height > 30 {
                        Text(timeText)
                            .font(.system(size: 10))
                            .foregroundColor(MadoColors.accent.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 4)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                .fill(MadoColors.accent.opacity(isHovered ? 0.18 : 0.12))
        )
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: MadoTheme.Radius.sm,
                bottomLeadingRadius: MadoTheme.Radius.sm,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(MadoColors.accent.opacity(0.6))
            .frame(width: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                .stroke(MadoColors.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .onHover { hovering in
            withAnimation(MadoTheme.Animation.quick) { isHovered = hovering }
        }
        .accessibilityLabel("Focus session\(taskTitle.map { ": \($0)" } ?? ""), \(session.durationSeconds / 60) minutes")
    }
}

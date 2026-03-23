import SwiftUI

struct EventBlockView: View {
    let event: CalendarEvent
    var onDelete: (() -> Void)?
    var onConvertToTask: (() -> Void)?
    var calendarColor: Color = MadoColors.calendarDefault
    var isPast: Bool = false
    @State private var isHovered = false

    private var isTaskBlock: Bool { event.sourceTaskId != nil }

    // Google Calendar API color IDs → hex
    private static let colorIdMap: [String: String] = [
        "1": "7986CB", "2": "33B679", "3": "8E24AA", "4": "E67C73",
        "5": "F6BF26", "6": "F4511E", "7": "039BE5", "8": "616161",
        "9": "3F51B5", "10": "0B8043", "11": "D50000",
    ]

    private var eventColor: Color {
        if isTaskBlock { return MadoColors.accent }
        if let colorId = event.colorId,
           let hex = Self.colorIdMap[colorId] {
            return Color(hex: hex)
        }
        return calendarColor
    }

    private var timeText: String {
        let formatter = DateFormatter()
        if AppSettings.shared.use24HourTime {
            formatter.dateFormat = "HH:mm"
            return "\(formatter.string(from: event.startDate)) \u{2013} \(formatter.string(from: event.endDate))"
        } else {
            formatter.dateFormat = "h:mm a"
            let text = "\(formatter.string(from: event.startDate)) \u{2013} \(formatter.string(from: event.endDate))"
            return text.replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
        }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Task blocks show a checkbox icon
                if isTaskBlock {
                    Image(systemName: "circle")
                        .font(.system(size: 10))
                        .foregroundColor(eventColor)
                        .padding(.leading, 6)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 11, weight: isTaskBlock ? .medium : .semibold))
                        .foregroundColor(event.isDeclined ? MadoColors.textTertiary : MadoColors.textPrimary)
                        .strikethrough(event.isDeclined, color: MadoColors.textTertiary)
                        .lineLimit(geo.size.height > 40 ? 2 : 1)

                    if geo.size.height > 30 {
                        Text(event.isAllDay ? "All day" : timeText)
                            .font(.system(size: 10))
                            .foregroundColor(event.isDeclined ? MadoColors.textPlaceholder : MadoColors.textSecondary)
                            .lineLimit(1)
                    }

                    if !isTaskBlock, let location = event.location, !location.isEmpty, geo.size.height > 50 {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin")
                                .font(.system(size: 7))
                            Text("\u{2191} \(location)")
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                        .foregroundColor(MadoColors.textTertiary)
                    }
                }
                .padding(.leading, isTaskBlock ? 4 : 8)
                .padding(.trailing, 4)

                Spacer(minLength: 0)

                if isHovered, let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(MadoColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                .fill(event.isPendingInvite
                    ? (isHovered ? eventColor.opacity(0.05) : Color.clear)
                    : event.isDeclined
                        ? eventColor.opacity(isPast ? 0.03 : 0.06)
                        : eventColor.opacity(isPast ? 0.10 : (isHovered ? 0.28 : 0.22)))
        )
        .overlay(
            (!isTaskBlock && !event.isPendingInvite && !event.isDeclined)
                ? RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .stroke(Color.white, lineWidth: 1)
                : nil
        )
        .overlay(alignment: .leading) {
            if isTaskBlock {
                UnevenRoundedRectangle(
                    topLeadingRadius: MadoTheme.Radius.sm,
                    bottomLeadingRadius: MadoTheme.Radius.sm,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .stroke(eventColor.opacity(isPast ? 0.5 : 0.8), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                .frame(width: 3)
            } else if event.isPendingInvite {
                UnevenRoundedRectangle(
                    topLeadingRadius: MadoTheme.Radius.sm,
                    bottomLeadingRadius: MadoTheme.Radius.sm,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .stroke(eventColor.opacity(isPast ? 0.4 : 0.7), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                .frame(width: 4)
            } else if event.isDeclined {
                UnevenRoundedRectangle(
                    topLeadingRadius: MadoTheme.Radius.sm,
                    bottomLeadingRadius: MadoTheme.Radius.sm,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(eventColor.opacity(isPast ? 0.15 : 0.3))
                .frame(width: 4)
            } else {
                UnevenRoundedRectangle(
                    topLeadingRadius: MadoTheme.Radius.sm,
                    bottomLeadingRadius: MadoTheme.Radius.sm,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(eventColor.opacity(isPast ? 0.5 : 1.0))
                .frame(width: 4)
            }
        }
        .overlay(
            (isTaskBlock || event.isPendingInvite) ? RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                .stroke(event.isPendingInvite ? eventColor.opacity(isPast ? 0.3 : 0.5) : eventColor.opacity(0.3),
                        style: event.isPendingInvite ? StrokeStyle(lineWidth: 1.5) : StrokeStyle(lineWidth: 1, dash: [4, 3])) : nil
        )
        .opacity(event.isDeclined ? (isPast ? 0.4 : 0.55) : (isPast ? 0.6 : 1.0))
        .onHover { hovering in
            withAnimation(MadoTheme.Animation.quick) { isHovered = hovering }
        }
        .contextMenu {
            if isTaskBlock {
                Button("Remove from Calendar") {
                    onDelete?()
                }
            } else {
                if let onConvertToTask {
                    Button("Add to Tasks") {
                        onConvertToTask()
                    }
                }
                Divider()
                if let onDelete {
                    Button("Delete Event", role: .destructive, action: onDelete)
                }
            }
        }
    }
}
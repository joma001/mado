import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct NextMeetingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextMeetingEntry {
        NextMeetingEntry(
            date: Date(),
            event: WidgetEvent(
                id: "placeholder",
                title: "Team Standup",
                startDate: Date().addingTimeInterval(1800),
                endDate: Date().addingTimeInterval(3600),
                isAllDay: false,
                colorHex: "4285F4",
                hasConference: true
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextMeetingEntry) -> Void) {
        let data = WidgetDataReader.read()
        let next = nextUpcomingEvent(from: data.events)
        completion(NextMeetingEntry(date: Date(), event: next))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextMeetingEntry>) -> Void) {
        let data = WidgetDataReader.read()
        let next = nextUpcomingEvent(from: data.events)

        // Refresh every 5 minutes for countdown accuracy
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let entry = NextMeetingEntry(date: Date(), event: next)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func nextUpcomingEvent(from events: [WidgetEvent]) -> WidgetEvent? {
        let now = Date()
        return events
            .filter { !$0.isAllDay && $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
    }
}

struct NextMeetingEntry: TimelineEntry {
    let date: Date
    let event: WidgetEvent?
}

// MARK: - Widget Definition

struct NextMeetingWidget: Widget {
    let kind = "NextMeetingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextMeetingProvider()) { entry in
            NextMeetingWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Meeting")
        .description("Countdown to your next event.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - View

struct NextMeetingWidgetView: View {
    let entry: NextMeetingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Next Up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let event = entry.event {
                Spacer()

                // Countdown
                Text(countdownText(to: event.startDate))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)

                // Event title
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)

                // Time
                HStack(spacing: 4) {
                    if event.hasConference {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.blue)
                    }
                    Text(event.shortTimeString)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            } else {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No upcoming\nmeetings")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }

    private func countdownText(to date: Date) -> String {
        let now = Date()
        let diff = date.timeIntervalSince(now)
        guard diff > 0 else { return "Now" }

        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

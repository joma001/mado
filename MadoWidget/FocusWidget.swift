import WidgetKit
import SwiftUI

// MARK: - Focus Widget Timeline Provider

struct FocusWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusWidgetEntry {
        FocusWidgetEntry(date: Date(), sessions: 3, minutes: 75)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusWidgetEntry) -> Void) {
        let data = WidgetDataReader.read()
        completion(FocusWidgetEntry(date: Date(), sessions: data.focusSessions, minutes: data.focusMinutes))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusWidgetEntry>) -> Void) {
        let data = WidgetDataReader.read()
        let entry = FocusWidgetEntry(date: Date(), sessions: data.focusSessions, minutes: data.focusMinutes)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct FocusWidgetEntry: TimelineEntry {
    let date: Date
    let sessions: Int
    let minutes: Int
}

// MARK: - Focus Widget View

struct FocusWidgetView: View {
    var entry: FocusWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Focus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(entry.sessions)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(entry.sessions == 1 ? "session" : "sessions")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if entry.minutes > 0 {
                Text("\(entry.minutes)m focused")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var mediumView: some View {
        HStack {
            smallView

            Divider().padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Focus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 16) {
                    VStack {
                        Text("\(entry.sessions)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Sessions")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        Text("\(entry.minutes)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Minutes")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

// MARK: - Widget Definition

struct FocusWidget: Widget {
    let kind: String = "FocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusWidgetProvider()) { entry in
            FocusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Focus")
        .description("Today's Pomodoro sessions and focus time")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

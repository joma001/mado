import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct EventsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> EventsEntry {
        EventsEntry(date: Date(), events: [
            WidgetEvent(id: "1", title: "Team Standup", startDate: Date(), endDate: Date().addingTimeInterval(1800), isAllDay: false, colorHex: "4285F4", hasConference: true),
            WidgetEvent(id: "2", title: "Lunch with Sarah", startDate: Date().addingTimeInterval(3600), endDate: Date().addingTimeInterval(7200), isAllDay: false, colorHex: "0B8043", hasConference: false),
        ])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (EventsEntry) -> Void) {
        let data = WidgetDataReader.read()
        completion(EventsEntry(date: Date(), events: data.events))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<EventsEntry>) -> Void) {
        let data = WidgetDataReader.read()
        let entry = EventsEntry(date: Date(), events: data.events)
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct EventsEntry: TimelineEntry {
    let date: Date
    let events: [WidgetEvent]
}

// MARK: - Widget Definition

struct TodayEventsWidget: Widget {
    let kind = "TodayEventsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EventsTimelineProvider()) { entry in
            TodayEventsWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Events")
        .description("See your calendar events for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct TodayEventsWidgetView: View {
    let entry: EventsEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallEventsView(events: entry.events)
        case .systemMedium:
            MediumEventsView(events: entry.events)
        default:
            SmallEventsView(events: entry.events)
        }
    }
}

// MARK: - Small (2×2)

private struct SmallEventsView: View {
    let events: [WidgetEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            if events.isEmpty {
                Spacer()
                Text("No events")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(events.prefix(3)) { event in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: event.colorHex) ?? .blue)
                            .frame(width: 3, height: 28)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text(event.shortTimeString)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Medium (4×2)

private struct MediumEventsView: View {
    let events: [WidgetEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Today's Events")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(todayString)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            
            if events.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No events today")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(events.prefix(4)) { event in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: event.colorHex) ?? .blue)
                            .frame(width: 3, height: 30)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Text(event.timeString)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if event.hasConference {
                            Image(systemName: "video.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.blue.opacity(0.7))
                        }
                    }
                }
                
                if events.count > 4 {
                    Text("+\(events.count - 4) more")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }
    
    private static let todayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private var todayString: String {
        Self.todayFormatter.string(from: Date())
    }
}

// MARK: - Color Helper

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let rgb = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}

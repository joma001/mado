import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct OverdueProvider: TimelineProvider {
    func placeholder(in context: Context) -> OverdueEntry {
        OverdueEntry(date: Date(), overdueTasks: [
            WidgetTask(id: "1", title: "Submit report", dueDate: Date().addingTimeInterval(-86400), isCompleted: false),
            WidgetTask(id: "2", title: "Reply to email", dueDate: Date().addingTimeInterval(-3600), isCompleted: false),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (OverdueEntry) -> Void) {
        let data = WidgetDataReader.read()
        let overdue = overdueTasksFrom(data.tasks)
        completion(OverdueEntry(date: Date(), overdueTasks: overdue))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OverdueEntry>) -> Void) {
        let data = WidgetDataReader.read()
        let overdue = overdueTasksFrom(data.tasks)
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let entry = OverdueEntry(date: Date(), overdueTasks: overdue)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func overdueTasksFrom(_ tasks: [WidgetTask]) -> [WidgetTask] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return tasks
            .filter { !$0.isCompleted && ($0.dueDate ?? .distantFuture) < startOfToday }
            .sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
    }
}

struct OverdueEntry: TimelineEntry {
    let date: Date
    let overdueTasks: [WidgetTask]
}

// MARK: - Widget Definition

struct OverdueWidget: Widget {
    let kind = "OverdueWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OverdueProvider()) { entry in
            OverdueWidgetView(entry: entry)
        }
        .configurationDisplayName("Overdue Tasks")
        .description("Track tasks that need attention.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct OverdueWidgetView: View {
    let entry: OverdueEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallOverdueView(tasks: entry.overdueTasks)
        case .systemMedium:
            MediumOverdueView(tasks: entry.overdueTasks)
        default:
            SmallOverdueView(tasks: entry.overdueTasks)
        }
    }
}

// MARK: - Small

private struct SmallOverdueView: View {
    let tasks: [WidgetTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.red)
                Text("Overdue")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if tasks.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.green)
                    Text("All caught up!")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Big count
                Text("\(tasks.count)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)

                Text(tasks.count == 1 ? "overdue task" : "overdue tasks")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                // Most overdue task
                if let oldest = tasks.first {
                    Text(oldest.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Medium

private struct MediumOverdueView: View {
    let tasks: [WidgetTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                Text("Overdue Tasks")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !tasks.isEmpty {
                    Text("\(tasks.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                }
            }

            if tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.green)
                        Text("All tasks on track!")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(tasks.prefix(4)) { task in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red.opacity(0.15))
                            .frame(width: 6, height: 6)

                        Text(task.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)

                        Spacer()

                        if let due = task.dueDate {
                            Text(daysAgoText(due))
                                .font(.system(size: 11))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                }

                if tasks.count > 4 {
                    Text("+\(tasks.count - 4) more")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }

    private func daysAgoText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }
}

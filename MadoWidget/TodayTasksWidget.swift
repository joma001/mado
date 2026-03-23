import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct TasksTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        TasksEntry(date: Date(), tasks: [
            WidgetTask(id: "1", title: "Review pull request", dueDate: Date(), isCompleted: false),
            WidgetTask(id: "2", title: "Update project docs", dueDate: Date(), isCompleted: false),
            WidgetTask(id: "3", title: "Send weekly report", dueDate: nil, isCompleted: false),
        ])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        let data = WidgetDataReader.read()
        completion(TasksEntry(date: Date(), tasks: data.tasks))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        let data = WidgetDataReader.read()
        let entry = TasksEntry(date: Date(), tasks: data.tasks)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct TasksEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
}

// MARK: - Widget Definition

struct TodayTasksWidget: Widget {
    let kind = "TodayTasksWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksTimelineProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Tasks")
        .description("See your pending tasks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct TodayTasksWidgetView: View {
    let entry: TasksEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallTasksView(tasks: entry.tasks)
        case .systemMedium:
            MediumTasksView(tasks: entry.tasks)
        default:
            SmallTasksView(tasks: entry.tasks)
        }
    }
}

// MARK: - Small (2×2)

private struct SmallTasksView: View {
    let tasks: [WidgetTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Tasks")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !tasks.isEmpty {
                    Text("\(tasks.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
            
            if tasks.isEmpty {
                Spacer()
                Text("All done!")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(tasks.prefix(3)) { task in
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(task.title)
                            .font(.system(size: 12))
                            .lineLimit(1)
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

private struct MediumTasksView: View {
    let tasks: [WidgetTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Today's Tasks")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !tasks.isEmpty {
                    Text("\(tasks.count) remaining")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            
            if tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.green)
                        Text("All tasks completed!")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(tasks.prefix(4)) { task in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange.opacity(0.7))
                        
                        Text(task.title)
                            .font(.system(size: 13))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let due = task.dueDate {
                            Text(shortTime(due))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
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
    
    private func shortTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }
}

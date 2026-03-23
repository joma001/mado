import SwiftUI

struct TodoRowView: View {
    let task: MadoTask
    let labels: [TaskLabel]
    var isSelected: Bool = false
    var onToggle: () -> Void
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onSnooze: ((Date) -> Void)?

    @State private var isHovered = false

    private var taskLabels: [TaskLabel] {
        labels.filter { task.labelIds.contains($0.id) }
    }

    private var dueDateText: String? {
        guard let date = task.dueDate else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var isDueOverdue: Bool {
        guard let date = task.dueDate else { return false }
        return date < Date() && !task.isCompleted
    }

    var body: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(
                        task.isCompleted ? MadoColors.checkboxChecked : MadoColors.checkboxUnchecked
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: MadoTheme.Spacing.xxxs) {
                Text(task.title)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(
                        task.isCompleted ? MadoColors.textTertiary : MadoColors.textPrimary
                    )
                    .strikethrough(task.isCompleted, color: MadoColors.textTertiary)
                    .lineLimit(1)

                if !taskLabels.isEmpty || dueDateText != nil || task.priority == .high {
                    HStack(spacing: MadoTheme.Spacing.xs) {
                        PriorityBadge(priority: task.priority)

                        ForEach(taskLabels, id: \.id) { label in
                            LabelChip(label: label)
                        }

                        if let due = dueDateText {
                            HStack(spacing: MadoTheme.Spacing.xxxs) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 9))
                                Text(due)
                                    .font(MadoTheme.Font.tiny)
                            }
                            .foregroundColor(isDueOverdue ? MadoColors.error : MadoColors.textTertiary)
                        }
                    }
                }
            }

            Spacer()

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(MadoColors.textTertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, MadoTheme.Spacing.xl)
        .padding(.vertical, MadoTheme.Spacing.sm)
        .frame(minHeight: MadoTheme.Layout.todoRowHeight)
        .background(
            isSelected
                ? MadoColors.selectedBackground
                : (isHovered ? MadoColors.hoverBackground : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(MadoTheme.Animation.quick) { isHovered = hovering }
        }
        .draggable(TransferableTask(from: task))
        .contextMenu {
            Button("Toggle Complete", action: onToggle)
            Divider()
            if let onSnooze {
                Menu("Snooze") {
                    Button("Later Today") {
                        let date = Calendar.current.date(byAdding: .hour, value: 3, to: Date())!
                        onSnooze(date)
                    }
                    Button("Tomorrow") {
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
                        let date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
                        onSnooze(date)
                    }
                    Button("Next Week") {
                        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Calendar.current.startOfDay(for: Date()))!
                        let date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek)!
                        onSnooze(date)
                    }
                }
                Divider()
            }
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

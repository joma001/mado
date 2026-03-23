import SwiftUI

struct SubtaskView: View {
    let subtasks: [MadoTask]
    var onToggle: (MadoTask) -> Void
    var onAdd: (String) -> Void

    @State private var newSubtaskText = ""
    @FocusState private var isAddingFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MadoTheme.Spacing.xs) {
            HStack {
                Text("Subtasks")
                    .font(MadoTheme.Font.captionMedium)
                    .foregroundColor(MadoColors.textSecondary)

                if !subtasks.isEmpty {
                    Text("\(subtasks.filter(\.isCompleted).count)/\(subtasks.count)")
                        .font(MadoTheme.Font.caption)
                        .foregroundColor(MadoColors.textTertiary)
                }

                Spacer()
            }

            if !subtasks.isEmpty {
                progressBar
            }

            ForEach(subtasks, id: \.id) { subtask in
                SubtaskRowView(subtask: subtask, onToggle: onToggle)
            }

            HStack(spacing: MadoTheme.Spacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .foregroundColor(MadoColors.textTertiary)

                TextField("Add subtask...", text: $newSubtaskText)
                    .textFieldStyle(.plain)
                    .font(MadoTheme.Font.callout)
                    .focused($isAddingFocused)
                    .onSubmit {
                        submitSubtask()
                    }
            }
            .padding(.vertical, MadoTheme.Spacing.xxs)
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        let completed = Double(subtasks.filter(\.isCompleted).count)
        let total = Double(subtasks.count)
        let progress = total > 0 ? completed / total : 0

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(MadoColors.surfaceTertiary)
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(progress >= 1.0 ? MadoColors.success : MadoColors.accent)
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(MadoTheme.Animation.standard, value: progress)
            }
        }
        .frame(height: 4)
    }

    private func submitSubtask() {
        let trimmed = newSubtaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        newSubtaskText = ""
    }
}

private struct SubtaskRowView: View {
    let subtask: MadoTask
    var onToggle: (MadoTask) -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            Button { onToggle(subtask) } label: {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(
                        subtask.isCompleted ? MadoColors.checkboxChecked : MadoColors.checkboxUnchecked
                    )
            }
            .buttonStyle(.plain)

            Text(subtask.title)
                .font(MadoTheme.Font.callout)
                .foregroundColor(
                    subtask.isCompleted ? MadoColors.textTertiary : MadoColors.textPrimary
                )
                .strikethrough(subtask.isCompleted, color: MadoColors.textTertiary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, MadoTheme.Spacing.xxxs)
        .padding(.horizontal, MadoTheme.Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.xs)
                .fill(isHovered ? MadoColors.hoverBackground : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

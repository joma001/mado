import SwiftUI

struct TodoDetailView: View {
    let task: MadoTask
    @Bindable var viewModel: TodoViewModel
    var onClose: () -> Void

    @State private var editingTitle: String = ""
    @State private var editingNotes: String = ""
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .foregroundColor(MadoColors.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: MadoTheme.Spacing.xl) {
                    titleSection
                    metadataSection
                    notesSection
                    subtasksSection
                }
                .padding(MadoTheme.Spacing.xl)
            }
        }
        .background(MadoColors.surface)
        .onAppear {
            editingTitle = task.title
            editingNotes = task.notes ?? ""
        }
        .onChange(of: task.id) {
            editingTitle = task.title
            editingNotes = task.notes ?? ""
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(MadoColors.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                viewModel.toggleTask(task)
            } label: {
                Text(task.isCompleted ? "Mark Incomplete" : "Mark Complete")
                    .font(MadoTheme.Font.caption)
            }
            .buttonStyle(MadoButtonStyle(variant: .secondary))

            Button(action: {
                viewModel.deleteTask(task)
                onClose()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(MadoColors.error)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MadoTheme.Spacing.lg)
        .padding(.vertical, MadoTheme.Spacing.md)
    }

    // MARK: - Title

    @ViewBuilder
    private var titleSection: some View {
        TextField("Task title", text: $editingTitle, axis: .vertical)
            .textFieldStyle(.plain)
            .font(MadoTheme.Font.title)
            .foregroundColor(MadoColors.textPrimary)
            .onChange(of: editingTitle) {
                task.title = editingTitle
                viewModel.updateTask(task)
            }
    }

    // MARK: - Metadata

    @ViewBuilder
    private var metadataSection: some View {
        VStack(spacing: MadoTheme.Spacing.md) {
            metadataRow(icon: "flag", label: "Priority") {
                Picker("", selection: Binding(
                    get: { task.priority },
                    set: { newValue in
                        task.priority = newValue
                        viewModel.updateTask(task)
                    }
                )) {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        Text(priority.label).tag(priority)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 120)
            }

            metadataRow(icon: "calendar", label: "Due Date") {
                let dueDateBinding = Binding<Date>(
                    get: { task.dueDate ?? Date() },
                    set: { newValue in
                        task.dueDate = newValue
                        viewModel.updateTask(task)
                    }
                )

                HStack(spacing: MadoTheme.Spacing.sm) {
                    DatePicker("", selection: dueDateBinding, displayedComponents: [.date])
                        .labelsHidden()

                    if task.dueDate != nil {
                        Button {
                            task.dueDate = nil
                            viewModel.updateTask(task)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(MadoColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            metadataRow(icon: "tag", label: "Labels") {
                labelsEditor
            }
        }
    }

    @ViewBuilder
    private func metadataRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: MadoTheme.Spacing.md) {
            HStack(spacing: MadoTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(MadoColors.textTertiary)
                    .frame(width: 16)

                Text(label)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textSecondary)
            }
            .frame(width: 100, alignment: .leading)

            content()

            Spacer()
        }
    }

    @ViewBuilder
    private var labelsEditor: some View {
        let taskLabels = viewModel.labels.filter { task.labelIds.contains($0.id) }

        FlowLayout(spacing: MadoTheme.Spacing.xxs) {
            ForEach(taskLabels, id: \.id) { label in
                LabelChip(label: label) {
                    task.labelIds.removeAll { $0 == label.id }
                    viewModel.updateTask(task)
                }
            }

            Menu {
                ForEach(viewModel.labels, id: \.id) { label in
                    Button {
                        if task.labelIds.contains(label.id) {
                            task.labelIds.removeAll { $0 == label.id }
                        } else {
                            task.labelIds.append(label.id)
                        }
                        viewModel.updateTask(task)
                    } label: {
                        HStack {
                            Text(label.name)
                            if task.labelIds.contains(label.id) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(MadoColors.textTertiary)
                    .padding(MadoTheme.Spacing.xxs)
                    .background(MadoColors.surfaceSecondary)
                    .clipShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: MadoTheme.Spacing.sm) {
            Text("Notes")
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(MadoColors.textSecondary)

            TextEditor(text: $editingNotes)
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(MadoTheme.Spacing.sm)
                .background(MadoColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.md))
                .onChange(of: editingNotes) {
                    task.notes = editingNotes.isEmpty ? nil : editingNotes
                    viewModel.updateTask(task)
                }
        }
    }

    // MARK: - Subtasks

    @ViewBuilder
    private var subtasksSection: some View {
        let subs = viewModel.subtasks(for: task)

        SubtaskView(
            subtasks: subs,
            onToggle: { subtask in
                viewModel.toggleTask(subtask)
            },
            onAdd: { title in
                viewModel.addSubtask(to: task, title: title)
            }
        )
    }
}

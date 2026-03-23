import SwiftUI

struct TaskDetailPopover: View {
    let task: MadoTask
    @Bindable var viewModel: TodoViewModel
    var onClose: () -> Void

    @State private var editingTitle: String = ""
    @State private var editingNotes: String = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider().foregroundColor(MadoColors.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: MadoTheme.Spacing.lg) {
                    titleSection
                    metadataSection
                    notesSection
                    linksSection
                    subtasksSection
                }
                .padding(MadoTheme.Spacing.lg)
            }
        }
        .frame(idealWidth: 340, maxWidth: 340, maxHeight: 480)
        .background(MadoColors.surface)
        .onAppear {
            editingTitle = task.title
            editingNotes = task.notes ?? ""
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: MadoTheme.Spacing.xs) {
            if task.gmailMessageId != nil {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }

            Spacer()

            Button {
                viewModel.toggleTask(task)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        .font(.system(size: 10, weight: .medium))
                    Text(task.isCompleted ? "Reopen" : "Done")
                        .font(MadoTheme.Font.caption)
                }
            }
            .buttonStyle(MadoButtonStyle(variant: .secondary))

            Button {
                viewModel.deleteTask(task)
                onClose()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(MadoColors.error)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(MadoColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
    }

    // MARK: - Title

    private var titleSection: some View {
        TextField("Task title", text: $editingTitle, axis: .vertical)
            .textFieldStyle(.plain)
            .font(MadoTheme.Font.headline)
            .foregroundColor(MadoColors.textPrimary)
            .focused($titleFocused)
            .onChange(of: editingTitle) {
                task.title = editingTitle
                viewModel.updateTask(task)
            }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(spacing: MadoTheme.Spacing.sm) {
            metaRow(icon: "flag", label: "Priority") {
                Picker("", selection: Binding(
                    get: { task.priority },
                    set: { task.priority = $0; viewModel.updateTask(task) }
                )) {
                    ForEach(TaskPriority.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 100)
            }

            metaRow(icon: "calendar", label: "Due") {
                HStack(spacing: MadoTheme.Spacing.xs) {
                    DatePicker("", selection: Binding(
                        get: { task.dueDate ?? Date() },
                        set: { task.dueDate = $0; viewModel.updateTask(task) }
                    ), displayedComponents: [.date])
                    .labelsHidden()

                    if task.dueDate != nil {
                        Button {
                            task.dueDate = nil
                            viewModel.updateTask(task)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(MadoColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            metaRow(icon: "folder", label: "Project") {
                Picker("", selection: Binding(
                    get: { task.projectId ?? "" },
                    set: { newId in
                        let pid = newId.isEmpty ? nil : newId
                        viewModel.moveTask(task, toProject: pid)
                    }
                )) {
                    Text("Inbox").tag("")
                    ForEach(viewModel.projects, id: \.id) { project in
                        Text(project.name).tag(project.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 120)
            }
        }
    }

    @ViewBuilder
    private func metaRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            HStack(spacing: MadoTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(MadoColors.textTertiary)
                    .frame(width: 14)
                Text(label)
                    .font(MadoTheme.Font.caption)
                    .foregroundColor(MadoColors.textSecondary)
            }
            .frame(width: 80, alignment: .leading)

            content()
            Spacer()
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: MadoTheme.Spacing.xs) {
            Text("Notes")
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(MadoColors.textSecondary)

            TextEditor(text: $editingNotes)
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60)
                .padding(MadoTheme.Spacing.sm)
                .background(MadoColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
                .onChange(of: editingNotes) {
                    task.notes = editingNotes.isEmpty ? nil : editingNotes
                    viewModel.updateTask(task)
                }
        }
    }

    // MARK: - Links

    @ViewBuilder
    private var linksSection: some View {
        let hasLinks = task.gmailMessageId != nil

        if hasLinks {
            VStack(alignment: .leading, spacing: MadoTheme.Spacing.xs) {
                Text("Links")
                    .font(MadoTheme.Font.captionMedium)
                    .foregroundColor(MadoColors.textSecondary)

                if let msgId = task.gmailMessageId {
                    linkRow(
                        icon: "envelope.fill",
                        iconColor: .red,
                        label: "Open in Gmail",
                        url: URL(string: "https://mail.google.com/mail/u/0/#inbox/\(msgId)")
                    )
                }
            }
        }
    }

    private func linkRow(icon: String, iconColor: Color, label: String, url: URL?) -> some View {
        Button {
            if let url { openExternalURL(url) }
        } label: {
            HStack(spacing: MadoTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                    .frame(width: 20, height: 20)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(label)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.accent)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundColor(MadoColors.textTertiary)
            }
            .padding(.horizontal, MadoTheme.Spacing.sm)
            .padding(.vertical, MadoTheme.Spacing.xs)
            .background(MadoColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subtasks

    @ViewBuilder
    private var subtasksSection: some View {
        let subs = viewModel.subtasks(for: task)

        if !subs.isEmpty || true {
            SubtaskView(
                subtasks: subs,
                onToggle: { viewModel.toggleTask($0) },
                onAdd: { viewModel.addSubtask(to: task, title: $0) }
            )
        }
    }
}

import SwiftUI

struct TodoFormView: View {
    @Bindable var viewModel: TodoViewModel
    @Binding var isPresented: Bool

    @State private var title = ""
    @State private var notes = ""
    @State private var priority: TaskPriority = .none
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var selectedLabelIds: [String] = []
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Task")
                    .font(MadoTheme.Font.title2)
                    .foregroundColor(MadoColors.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(MadoColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(MadoTheme.Spacing.xl)

            Divider()
                .foregroundColor(MadoColors.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: MadoTheme.Spacing.xl) {
                    TextField("Task title", text: $title)
                        .textFieldStyle(.plain)
                        .font(MadoTheme.Font.title)
                        .foregroundColor(MadoColors.textPrimary)
                        .focused($isTitleFocused)

                    TextEditor(text: $notes)
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60)
                        .padding(MadoTheme.Spacing.sm)
                        .background(MadoColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.md))

                    VStack(alignment: .leading, spacing: MadoTheme.Spacing.lg) {
                        formRow(icon: "flag", label: "Priority") {
                            Picker("", selection: $priority) {
                                ForEach(TaskPriority.allCases, id: \.self) { p in
                                    Text(p.label).tag(p)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }

                        formRow(icon: "calendar", label: "Due Date") {
                            Toggle("", isOn: $hasDueDate)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)

                            if hasDueDate {
                                DatePicker("", selection: $dueDate, displayedComponents: [.date])
                                    .labelsHidden()
                            }
                        }

                        formRow(icon: "tag", label: "Labels") {
                            labelsSelector
                        }
                    }
                }
                .padding(MadoTheme.Spacing.xl)
            }

            Divider()
                .foregroundColor(MadoColors.divider)

            HStack {
                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(MadoButtonStyle(variant: .secondary))

                Button("Create") {
                    createTask()
                }
                .buttonStyle(MadoButtonStyle(variant: .primary))
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(MadoTheme.Spacing.lg)
        }
        .frame(width: 500, height: 520)
        .background(MadoColors.surface)
        .onAppear {
            isTitleFocused = true
        }
    }

    @ViewBuilder
    private func formRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
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
            .frame(width: 90, alignment: .leading)

            content()

            Spacer()
        }
    }

    @ViewBuilder
    private var labelsSelector: some View {
        FlowLayout(spacing: MadoTheme.Spacing.xs) {
            ForEach(viewModel.labels, id: \.id) { label in
                Button {
                    if selectedLabelIds.contains(label.id) {
                        selectedLabelIds.removeAll { $0 == label.id }
                    } else {
                        selectedLabelIds.append(label.id)
                    }
                } label: {
                    HStack(spacing: MadoTheme.Spacing.xxs) {
                        if selectedLabelIds.contains(label.id) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        Text(label.name)
                            .font(MadoTheme.Font.caption)
                    }
                    .foregroundColor(label.color.foreground)
                    .padding(.horizontal, MadoTheme.Spacing.sm)
                    .padding(.vertical, MadoTheme.Spacing.xxs)
                    .background(
                        selectedLabelIds.contains(label.id)
                            ? label.color.background
                            : label.color.background.opacity(0.5)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                selectedLabelIds.contains(label.id) ? label.color.foreground.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func createTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        for t in viewModel.tasks { t.position += 1 }
        let task = MadoTask(
            title: trimmed,
            notes: notes.isEmpty ? nil : notes,
            dueDate: hasDueDate ? dueDate : nil,
            priority: priority,
            labelIds: selectedLabelIds,
            position: 0
        )

        DataController.shared.createTask(task)
        viewModel.loadTasks()
        isPresented = false
    }
}

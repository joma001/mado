import SwiftUI

struct TodoListView: View {
    @Bindable var viewModel: TodoViewModel

    @State private var showingForm = false

    var body: some View {
        HSplitView {
            // MARK: - Left: Task List
            VStack(spacing: 0) {

                VStack(spacing: MadoTheme.Spacing.md) {
                    HStack {
                        Text("Tasks")
                            .font(MadoTheme.Font.title)
                            .foregroundColor(MadoColors.textPrimary)

                        Spacer()

                        Button {
                            showingForm = true
                        } label: {
                            Image(systemName: "plus.square")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .buttonStyle(MadoButtonStyle(variant: .ghost))
                        .help("New Task")
                    }


                    HStack(spacing: MadoTheme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(MadoColors.textTertiary)

                        TextField("Search tasks...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(MadoTheme.Font.body)
                    }
                    .padding(.horizontal, MadoTheme.Spacing.sm)
                    .padding(.vertical, MadoTheme.Spacing.xs)
                    .background(MadoColors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.md))


                    HStack(spacing: MadoTheme.Spacing.sm) {
                        filterButton("All", isActive: viewModel.filterPriority == nil) {
                            viewModel.filterPriority = nil
                        }
                        filterButton("High", isActive: viewModel.filterPriority == .high) {
                            viewModel.filterPriority = .high
                        }
                        filterButton("Medium", isActive: viewModel.filterPriority == .medium) {
                            viewModel.filterPriority = .medium
                        }
                        filterButton("Low", isActive: viewModel.filterPriority == .low) {
                            viewModel.filterPriority = .low
                        }

                        Spacer()

                        Button {
                            withAnimation(MadoTheme.Animation.quick) {
                                viewModel.showCompleted.toggle()
                            }
                        } label: {
                            HStack(spacing: MadoTheme.Spacing.xxs) {
                                Image(systemName: viewModel.showCompleted ? "eye.fill" : "eye.slash")
                                    .font(.system(size: 11))
                                Text(viewModel.showCompleted ? "Hide done" : "Show done")
                                    .font(MadoTheme.Font.caption)
                            }
                            .foregroundColor(MadoColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MadoTheme.Spacing.xl)
                .padding(.top, MadoTheme.Spacing.xl)
                .padding(.bottom, MadoTheme.Spacing.md)

                Divider()
                    .foregroundColor(MadoColors.divider)


                if viewModel.filteredTasks.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: viewModel.searchText.isEmpty ? "No tasks yet" : "No results",
                        subtitle: viewModel.searchText.isEmpty
                            ? "Create your first task to get started"
                            : "Try a different search term",
                        buttonTitle: viewModel.searchText.isEmpty ? "New Task" : nil,
                        onAction: viewModel.searchText.isEmpty ? { showingForm = true } : nil
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.filteredTasks, id: \.id) { task in
                                TodoRowView(
                                    task: task,
                                    labels: viewModel.labels,
                                    isSelected: viewModel.selectedTask?.id == task.id,
                                    onToggle: { viewModel.toggleTask(task) },
                                    onSelect: { viewModel.selectedTask = task },
                                    onDelete: { viewModel.deleteTask(task) },
                                    onSnooze: { date in viewModel.snoozeTask(task, to: date) }
                                )
                            }
                        }
                        .padding(.vertical, MadoTheme.Spacing.xs)
                    }
                }

                Spacer(minLength: 0)


                QuickAddField(placeholder: "Add a task...") { title in
                    viewModel.addTask(title: title)
                }
                .padding(.horizontal, MadoTheme.Spacing.lg)
                .padding(.vertical, MadoTheme.Spacing.md)
            }
            .frame(minWidth: 340, idealWidth: 400)
            .background(MadoColors.surface)

            // MARK: - Right: Detail Panel
            if let selected = viewModel.selectedTask {
                TodoDetailView(
                    task: selected,
                    viewModel: viewModel,
                    onClose: { viewModel.selectedTask = nil }
                )
                .frame(minWidth: 300, idealWidth: 360)
            }
        }
        .onAppear {
            viewModel.loadTasks()
            viewModel.loadLabels()
        }
        .sheet(isPresented: $showingForm) {
            TodoFormView(viewModel: viewModel, isPresented: $showingForm)
        }
    }

    // MARK: - Filter Button
    @ViewBuilder
    private func filterButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(MadoTheme.Animation.quick) { action() }
        }) {
            Text(title)
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(isActive ? MadoColors.accent : MadoColors.textSecondary)
                .padding(.horizontal, MadoTheme.Spacing.sm)
                .padding(.vertical, MadoTheme.Spacing.xxs)
                .background(
                    isActive ? MadoColors.accentLight : Color.clear
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

struct SearchOverlay: View {
    @Binding var isPresented: Bool
    var calendarVM: CalendarViewModel
    var todoVM: TodoViewModel

    @State private var searchManager = SearchManager()
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Search input
                HStack(spacing: MadoTheme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(MadoColors.textTertiary)

                    TextField("Search tasks and events...", text: $searchManager.query)
                        .textFieldStyle(.plain)
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textPrimary)
                        .focused($isFocused)
                        .onChange(of: searchManager.query) { _, _ in
                            searchManager.search()
                        }
                        #if os(macOS)
                        .onExitCommand { dismiss() }
                        #endif

                    if !searchManager.query.isEmpty {
                        Button {
                            searchManager.clear()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(MadoColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MadoTheme.Spacing.lg)
                .padding(.vertical, MadoTheme.Spacing.md)

                if !searchManager.query.isEmpty {
                    Divider().foregroundColor(MadoColors.divider)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if searchManager.hasResults {
                                // Task results
                                if !searchManager.taskResults.isEmpty {
                                    sectionHeader("Tasks", count: searchManager.taskResults.count)

                                    ForEach(searchManager.taskResults) { task in
                                        taskRow(task)
                                    }
                                }

                                // Event results
                                if !searchManager.eventResults.isEmpty {
                                    sectionHeader("Events", count: searchManager.eventResults.count)

                                    ForEach(searchManager.eventResults) { event in
                                        eventRow(event)
                                    }
                                }
                            } else {
                                HStack {
                                    Spacer()
                                    Text("No results")
                                        .font(MadoTheme.Font.body)
                                        .foregroundColor(MadoColors.textTertiary)
                                    Spacer()
                                }
                                .padding(MadoTheme.Spacing.xl)
                            }
                        }
                    }
                    .frame(maxHeight: 400)
                }
            }
            .frame(width: 520)
            .background(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.xl)
                    .fill(MadoColors.surface)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            )
            .padding(.top, 100)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear { isFocused = true }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(MadoColors.textTertiary)

            Text("\(count)")
                .font(MadoTheme.Font.tiny)
                .foregroundColor(MadoColors.textTertiary)

            Spacer()
        }
        .padding(.horizontal, MadoTheme.Spacing.lg)
        .padding(.top, MadoTheme.Spacing.md)
        .padding(.bottom, MadoTheme.Spacing.xs)
    }

    // MARK: - Task Row

    private func taskRow(_ task: MadoTask) -> some View {
        Button {
            todoVM.selectedTask = task
            dismiss()
        } label: {
            HStack(spacing: MadoTheme.Spacing.sm) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(task.isCompleted ? MadoColors.checkboxChecked : MadoColors.checkboxUnchecked)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(MadoTheme.Font.body)
                        .foregroundColor(task.isCompleted ? MadoColors.textTertiary : MadoColors.textPrimary)
                        .strikethrough(task.isCompleted)
                        .lineLimit(1)

                    if let dueDate = task.dueDate {
                        Text(dueDate, format: .dateTime.month().day())
                            .font(MadoTheme.Font.tiny)
                            .foregroundColor(MadoColors.textTertiary)
                    }
                }

                Spacer()

                Text("Task")
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(MadoColors.textTertiary)
            }
            .padding(.horizontal, MadoTheme.Spacing.lg)
            .padding(.vertical, MadoTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Event Row

    private func eventRow(_ event: CalendarEvent) -> some View {
        Button {
            calendarVM.selectedDate = event.startDate
            calendarVM.selectedEvent = event
            calendarVM.loadEvents()
            dismiss()
        } label: {
            HStack(spacing: MadoTheme.Spacing.sm) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(MadoColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: MadoTheme.Spacing.xs) {
                        Text(event.startDate, format: .dateTime.month().day().hour().minute())
                            .font(MadoTheme.Font.tiny)
                            .foregroundColor(MadoColors.textTertiary)

                        if let loc = event.location, !loc.isEmpty {
                            Text("· \(loc)")
                                .font(MadoTheme.Font.tiny)
                                .foregroundColor(MadoColors.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Text("Event")
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(MadoColors.textTertiary)
            }
            .padding(.horizontal, MadoTheme.Spacing.lg)
            .padding(.vertical, MadoTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dismiss() {
        searchManager.clear()
        withAnimation(MadoTheme.Animation.quick) {
            isPresented = false
        }
    }
}

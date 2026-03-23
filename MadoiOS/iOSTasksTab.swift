import SwiftUI

enum iOSTaskFilter: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case upcoming = "Upcoming"
    case overdue = "Overdue"
    case noDate = "No Date"
}

struct iOSTasksTab: View {
    @Bindable var viewModel = TodoViewModel()
    @State private var selectedTask: MadoTask?
    @State private var selectedFilter: iOSTaskFilter = .all
    @State private var selectedPriority: TaskPriority? = nil
    @State private var isEditing = false
    @State private var selectedTaskIds: Set<String> = []
    @State private var taskToSchedule: MadoTask?
    @State private var scheduleDate = Date()

    private var displayTasks: [MadoTask] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())

        var result = viewModel.filteredTasks.filter { !$0.isCompleted }

        // Apply section filter
        switch selectedFilter {
        case .all:
            break
        case .today:
            result = result.filter { task in
                guard let due = task.dueDate else { return false }
                return cal.isDateInToday(due) || due < startOfToday
            }
        case .upcoming:
            result = result.filter { task in
                guard let due = task.dueDate else { return false }
                return due >= startOfToday
            }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .overdue:
            result = result.filter { task in
                guard let due = task.dueDate else { return false }
                return due < startOfToday
            }
        case .noDate:
            result = result.filter { $0.dueDate == nil }
        }

        // Apply priority filter
        if let priority = selectedPriority {
            result = result.filter { $0.priority == priority }
        }

        return result
    }

    private var completedTasks: [MadoTask] {
        viewModel.filteredTasks.filter { $0.isCompleted }
    }

    private var filterCounts: [iOSTaskFilter: Int] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let active = viewModel.filteredTasks.filter { !$0.isCompleted }
        return [
            .all: active.count,
            .today: active.filter { task in
                guard let due = task.dueDate else { return false }
                return cal.isDateInToday(due) || due < startOfToday
            }.count,
            .upcoming: active.filter { task in
                guard let due = task.dueDate else { return false }
                return due >= startOfToday
            }.count,
            .overdue: active.filter { task in
                guard let due = task.dueDate else { return false }
                return due < startOfToday
            }.count,
            .noDate: active.filter { $0.dueDate == nil }.count,
        ]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                filterChipsBar

                // Priority filter
                if selectedPriority != nil {
                    activePriorityChip
                }

                List {
                    if displayTasks.isEmpty {
                        emptyFilterState
                    } else {
                        Section {
                            ForEach(displayTasks) { task in
                                iOSTaskListRow(
                                    task: task,
                                    isSelected: isEditing && selectedTaskIds.contains(task.id),
                                    isEditing: isEditing,
                                    onToggle: {
                                        if isEditing {
                                            toggleSelection(task)
                                        } else {
                                            viewModel.toggleTask(task)
                                        }
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteTask(task)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        viewModel.toggleTask(task)
                                    } label: {
                                        Label("Done", systemImage: "checkmark")
                                    }
                                    .tint(MadoColors.success)
                                    Button {
                                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
                                        let date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
                                        viewModel.snoozeTask(task, to: date)
                                    } label: {
                                        Label("Tomorrow", systemImage: "moon.fill")
                                    }
                                    .tint(MadoColors.accent)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isEditing {
                                        toggleSelection(task)
                                    } else {
                                        selectedTask = task
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        taskToSchedule = task
                                        scheduleDate = task.dueDate ?? Date()
                                    } label: {
                                        Label("Schedule", systemImage: "calendar.badge.clock")
                                    }
                                    Menu("Snooze") {
                                        Button("Later Today") {
                                            let later = Calendar.current.date(byAdding: .hour, value: 3, to: Date())!
                                            viewModel.snoozeTask(task, to: later)
                                        }
                                        Button("Tomorrow") {
                                            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
                                            let date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
                                            viewModel.snoozeTask(task, to: date)
                                        }
                                        Button("Next Week") {
                                            let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Calendar.current.startOfDay(for: Date()))!
                                            let date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek)!
                                            viewModel.snoozeTask(task, to: date)
                                        }
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        viewModel.deleteTask(task)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text(selectedFilter == .all ? "Tasks" : selectedFilter.rawValue)
                                Spacer()
                                Text("\(displayTasks.count)")
                                    .font(.caption2)
                                    .foregroundColor(MadoColors.textTertiary)
                            }
                        }
                    }

                    // Completed tasks
                    if !completedTasks.isEmpty && selectedFilter == .all {
                        Section(isExpanded: .constant(false)) {
                            ForEach(completedTasks) { task in
                                iOSTaskListRow(task: task, isSelected: false, isEditing: false) {
                                    viewModel.toggleTask(task)
                                }
                            }
                        } header: {
                            Text("Completed (\(completedTasks.count))")
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Batch action bar
                if isEditing && !selectedTaskIds.isEmpty {
                    batchActionBar
                }
            }
            .navigationTitle("Tasks")
            .searchable(text: $viewModel.searchText, prompt: "Search tasks...")
            .onChange(of: viewModel.searchText) { _, _ in viewModel.loadTasks() }
            .refreshable {
                await SyncEngine.shared.syncAll()
                viewModel.loadTasks()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section("Priority") {
                            Button {
                                selectedPriority = nil
                            } label: {
                                HStack {
                                    Text("Any Priority")
                                    if selectedPriority == nil { Image(systemName: "checkmark") }
                                }
                            }
                            ForEach([TaskPriority.high, .medium, .low], id: \.self) { p in
                                Button {
                                    selectedPriority = selectedPriority == p ? nil : p
                                } label: {
                                    HStack {
                                        Label(p.label, systemImage: "flag.fill")
                                        if selectedPriority == p { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .foregroundColor(selectedPriority != nil ? MadoColors.accent : MadoColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            isEditing.toggle()
                            if !isEditing { selectedTaskIds.removeAll() }
                        }
                    } label: {
                        Text(isEditing ? "Done" : "Select")
                            .font(.subheadline)
                    }
                }
            }
            .sheet(item: $selectedTask) { task in
                iOSTaskDetailSheet(task: task, viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $taskToSchedule) { task in
                NavigationStack {
                    Form {
                        DatePicker("Date & Time", selection: $scheduleDate)
                            .datePickerStyle(.graphical)
                    }
                    .navigationTitle("Schedule Task")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { taskToSchedule = nil }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save") {
                                task.dueDate = scheduleDate
                                task.markUpdated()
                                DataController.shared.save()
                                SyncEngine.shared.schedulePush()
                                viewModel.loadTasks()
                                taskToSchedule = nil
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear { viewModel.loadTasks() }
        }
    }

    // MARK: - Filter Chips Bar

    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(iOSTaskFilter.allCases, id: \.self) { filter in
                    let count = filterCounts[filter] ?? 0
                    let isActive = selectedFilter == filter

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filterIcon(filter))
                                .font(.system(size: 10))
                            Text(filter.rawValue)
                                .font(.system(size: 12, weight: .medium))
                            if count > 0 && !isActive {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(filterColor(filter).opacity(0.8))
                            }
                        }
                        .foregroundColor(isActive ? .white : filterColor(filter))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isActive ? filterColor(filter) : filterColor(filter).opacity(0.1))
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(MadoColors.surface)
    }

    private var activePriorityChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "flag.fill")
                .font(.system(size: 10))
            Text(selectedPriority?.label ?? "")
                .font(.system(size: 12, weight: .medium))
            Button {
                withAnimation { selectedPriority = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
            }
        }
        .foregroundColor(priorityColor(selectedPriority ?? .none))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(priorityColor(selectedPriority ?? .none).opacity(0.1))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var emptyFilterState: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: filterIcon(selectedFilter))
                    .font(.system(size: 28))
                    .foregroundColor(MadoColors.textTertiary.opacity(0.5))
                Text("No \(selectedFilter.rawValue.lowercased()) tasks")
                    .font(MadoTheme.Font.caption)
                    .foregroundColor(MadoColors.textTertiary)
                if selectedFilter != .all {
                    Button("Show all tasks") {
                        withAnimation { selectedFilter = .all }
                    }
                    .font(.caption)
                    .foregroundColor(MadoColors.accent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Batch Action Bar

    private var batchActionBar: some View {
        HStack(spacing: 16) {
            Button {
                batchComplete()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                    Text("Done")
                        .font(.system(size: 10))
                }
            }

            Button {
                batchSnooze()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 20))
                    Text("Tomorrow")
                        .font(.system(size: 10))
                }
            }

            Button(role: .destructive) {
                batchDelete()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20))
                    Text("Delete")
                        .font(.system(size: 10))
                }
            }

            Spacer()

            Text("\(selectedTaskIds.count) selected")
                .font(.caption)
                .foregroundColor(MadoColors.textSecondary)

            Button("All") {
                selectedTaskIds = Set(displayTasks.map(\.id))
            }
            .font(.caption)
            .foregroundColor(MadoColors.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(MadoColors.surfaceSecondary)
    }

    // MARK: - Helpers

    private func toggleSelection(_ task: MadoTask) {
        if selectedTaskIds.contains(task.id) {
            selectedTaskIds.remove(task.id)
        } else {
            selectedTaskIds.insert(task.id)
        }
    }

    private func batchComplete() {
        let tasks = viewModel.filteredTasks.filter { selectedTaskIds.contains($0.id) }
        for task in tasks { viewModel.toggleTask(task) }
        selectedTaskIds.removeAll()
        isEditing = false
    }

    private func batchSnooze() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        let date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
        let tasks = viewModel.filteredTasks.filter { selectedTaskIds.contains($0.id) }
        for task in tasks { viewModel.snoozeTask(task, to: date) }
        selectedTaskIds.removeAll()
        isEditing = false
    }

    private func batchDelete() {
        let tasks = viewModel.filteredTasks.filter { selectedTaskIds.contains($0.id) }
        for task in tasks { viewModel.deleteTask(task) }
        selectedTaskIds.removeAll()
        isEditing = false
    }

    private func filterIcon(_ filter: iOSTaskFilter) -> String {
        switch filter {
        case .all: return "tray.fill"
        case .today: return "calendar"
        case .upcoming: return "clock"
        case .overdue: return "exclamationmark.circle"
        case .noDate: return "calendar.badge.minus"
        }
    }

    private func filterColor(_ filter: iOSTaskFilter) -> Color {
        switch filter {
        case .all: return MadoColors.accent
        case .today: return MadoColors.accent
        case .upcoming: return .blue
        case .overdue: return MadoColors.error
        case .noDate: return MadoColors.textSecondary
        }
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high: return MadoColors.priorityHigh
        case .medium: return MadoColors.priorityMedium
        case .low: return MadoColors.priorityLow
        case .none: return MadoColors.textTertiary
        }
    }
}

// MARK: - Task List Row

private struct iOSTaskListRow: View {
    let task: MadoTask
    var isSelected: Bool = false
    var isEditing: Bool = false
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? MadoColors.accent : MadoColors.textTertiary)
            } else {
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(task.isCompleted ? MadoColors.checkboxChecked : MadoColors.checkboxUnchecked)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(task.isCompleted ? MadoColors.textTertiary : MadoColors.textPrimary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(1)

                if let dueDate = task.dueDate {
                    Text(dueDateText(dueDate))
                        .font(MadoTheme.Font.tiny)
                        .foregroundColor(isOverdue(dueDate) ? MadoColors.error : MadoColors.textTertiary)
                }
            }

            Spacer()

            iOSTaskPriorityBadge(priority: task.priority)
        }
        .padding(.vertical, 2)
    }

    private func dueDateText(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Task Detail Sheet

private struct iOSTaskDetailSheet: View {
    let task: MadoTask
    let viewModel: TodoViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editedTitle: String
    @State private var editedNotes: String

    init(task: MadoTask, viewModel: TodoViewModel) {
        self.task = task
        self.viewModel = viewModel
        _editedTitle = State(initialValue: task.title)
        _editedNotes = State(initialValue: task.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $editedTitle)
                        .font(MadoTheme.Font.body)
                }

                Section("Notes") {
                    TextEditor(text: $editedNotes)
                        .frame(minHeight: 80)
                        .font(MadoTheme.Font.body)
                }

                Section("Priority") {
                    Picker("Priority", selection: Binding(
                        get: { task.priority },
                        set: { task.priority = $0 }
                    )) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Due Date") {
                    Toggle("Has Due Date", isOn: Binding(
                        get: { task.dueDate != nil },
                        set: { enabled in
                            task.dueDate = enabled ? Date() : nil
                        }
                    ))
                    if task.dueDate != nil {
                        DatePicker("Date", selection: Binding(
                            get: { task.dueDate ?? Date() },
                            set: { task.dueDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.deleteTask(task)
                        dismiss()
                    } label: {
                        Label("Delete Task", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Task Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        task.title = editedTitle
                        task.notes = editedNotes.isEmpty ? nil : editedNotes
                        task.localUpdatedAt = Date()
                        task.needsSync = true
                        DataController.shared.save()
                        SyncEngine.shared.schedulePush()
                        viewModel.loadTasks()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Priority Badge

private struct iOSTaskPriorityBadge: View {
    let priority: TaskPriority

    private var label: String? {
        switch priority {
        case .high: return "1"
        case .medium: return "2"
        case .low: return "3"
        case .none: return nil
        }
    }

    private var color: Color {
        switch priority {
        case .high: return MadoColors.priorityHigh
        case .medium: return MadoColors.priorityMedium
        case .low: return MadoColors.priorityLow
        case .none: return .clear
        }
    }

    var body: some View {
        if let label {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .frame(width: 18, height: 18)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}

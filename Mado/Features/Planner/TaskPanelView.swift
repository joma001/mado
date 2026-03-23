import SwiftUI

enum TaskPanelSection: Hashable {
    case inbox
    case starred
    case today
    case upcoming
    case archive
    case project(String)
}

enum TaskSortMode: String, CaseIterable {
    case manual = "Default"
    case date = "Date"
    case priority = "Priority"
    case created = "Created"
}

struct TaskPanelView: View {
    @Bindable var viewModel: TodoViewModel
    var calendarVM: CalendarViewModel?
    @Binding var showMemos: Bool

    @State private var selectedSection: TaskPanelSection = .inbox
    @State private var isAddingProject = false
    @State private var newProjectName = ""
    @State private var quickAddText = ""
    @State private var selectedTaskForDetail: MadoTask?
    @State private var focusedTaskId: String?
    @State private var hoveredSection: TaskPanelSection?
    @State private var hoveredProjectId: String?
    @FocusState private var isQuickAddFocused: Bool
    @State private var showFilterBar = false
    @State private var filterPriorities: Set<TaskPriority> = []
    @State private var filterHasDate: Bool? = nil
    @State private var filterLabelIds: Set<String> = []
    @State private var sortMode: TaskSortMode = .manual
    @State private var isFilterHovered = false

    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif
    private let auth = AuthenticationManager.shared
    private let sync = SyncEngine.shared

    private var sectionTasks: [MadoTask] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())

        switch selectedSection {
        case .inbox:
            return viewModel.topLevelTasks.filter { !$0.isCompleted }
        case .starred:
            return viewModel.topLevelTasks
                .filter { !$0.isCompleted && $0.gmailMessageId != nil }
        case .today:
            return viewModel.topLevelTasks
                .filter { !$0.isCompleted }
                .filter { task in
                    guard let due = task.dueDate else { return false }
                    return cal.isDateInToday(due) || due < startOfToday
                }
        case .upcoming:
            return viewModel.topLevelTasks
                .filter { !$0.isCompleted }
                .filter { task in
                    guard let due = task.dueDate else { return false }
                    return due >= startOfToday
                }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .archive:
            return viewModel.topLevelTasks
                .filter { $0.isCompleted }
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        case .project(let id):
            return viewModel.topLevelTasks
                .filter { !$0.isCompleted && $0.projectId == id }
        }
    }

    private var filteredTasks: [MadoTask] {
        var result = sectionTasks
        if !filterPriorities.isEmpty {
            result = result.filter { filterPriorities.contains($0.priority) }
        }
        if let hasDate = filterHasDate {
            result = result.filter { hasDate ? $0.dueDate != nil : $0.dueDate == nil }
        }
        if !filterLabelIds.isEmpty {
            result = result.filter { task in
                !Set(task.labelIds).isDisjoint(with: filterLabelIds)
            }
        }
        switch sortMode {
        case .manual: break
        case .date: result.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .priority: result.sort { $0.priority.sortOrder > $1.priority.sortOrder }
        case .created: result.sort { $0.createdAt > $1.createdAt }
        }
        return result
    }

    private var activeFilterCount: Int {
        var count = 0
        if !filterPriorities.isEmpty { count += filterPriorities.count }
        if filterHasDate != nil { count += 1 }
        if !filterLabelIds.isEmpty { count += filterLabelIds.count }
        return count
    }

    private var isAnyFilterActive: Bool {
        activeFilterCount > 0 || sortMode != .manual
    }

    private var overdueTasks: [MadoTask] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return filteredTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due < startOfToday
        }
    }

    private var nonOverdueTasks: [MadoTask] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return filteredTasks.filter { task in
            guard let due = task.dueDate else { return true }
            return due >= startOfToday
        }
    }

    private var allTasksCount: Int {
        viewModel.topLevelTasks.filter { !$0.isCompleted }.count
    }

    private var todayCount: Int {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        return viewModel.topLevelTasks.filter { !$0.isCompleted }.filter { task in
            guard let due = task.dueDate else { return false }
            return cal.isDateInToday(due) || due < startOfToday
        }.count
    }

    private var archiveCount: Int {
        viewModel.topLevelTasks.filter { $0.isCompleted }.count
    }

    private var starredCount: Int {
        viewModel.topLevelTasks.filter { !$0.isCompleted && $0.gmailMessageId != nil }.count
    }


    private var allVisibleTasks: [MadoTask] {
        overdueTasks + nonOverdueTasks
    }

    private var focusedTask: MadoTask? {
        guard let id = focusedTaskId else { return nil }
        return allVisibleTasks.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebarNav
            Divider().foregroundColor(MadoColors.divider)
            taskListArea
        }
        .frame(maxWidth: .infinity)
        .background(MadoColors.sidebar)
        .onAppear { viewModel.loadAll() }
        .background {
            // Tab shortcuts: ⌘1 Inbox, ⌘2 Today, ⌘3 Notes
            Group {
                Button("") {
                    withAnimation(MadoTheme.Animation.quick) {
                        selectedSection = .inbox
                        showMemos = false
                    }
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("") {
                    withAnimation(MadoTheme.Animation.quick) {
                        selectedSection = .today
                        showMemos = false
                    }
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("") {
                    withAnimation(MadoTheme.Animation.standard) {
                        showMemos.toggle()
                    }
                }
                .keyboardShortcut("3", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }

    private var sidebarNav: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 1) {
                sidebarItem(icon: "tray.fill", label: "Inbox", section: .inbox, count: allTasksCount)
                sidebarItem(icon: "star.fill", label: "Starred", section: .starred, count: starredCount)
                sidebarItem(icon: "calendar", label: "Today", section: .today, count: todayCount)
                sidebarItem(icon: "clock", label: "Upcoming", section: .upcoming, hasChevron: true)
                sidebarItem(icon: "archivebox.fill", label: "Archive", section: .archive, count: archiveCount)

                Divider().foregroundColor(MadoColors.divider).padding(.horizontal, MadoTheme.Spacing.sm).padding(.vertical, 4)

                notesNavItem
            }
            .padding(.vertical, MadoTheme.Spacing.sm)

            Divider().foregroundColor(MadoColors.divider).padding(.horizontal, MadoTheme.Spacing.sm)

            HStack {
                Text("Projects")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(MadoColors.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    isAddingProject = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(MadoColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MadoTheme.Spacing.md)
            .padding(.top, MadoTheme.Spacing.sm)
            .padding(.bottom, MadoTheme.Spacing.xs)

            ScrollView {
                VStack(spacing: 1) {
                    if isAddingProject {
                        addProjectRow
                    }
                    ForEach(viewModel.projects, id: \.id) { project in
                        projectNavItem(project)
                    }
                }
            }

            Spacer()

            panelFooter
        }
        .frame(width: 170)
        .background(MadoColors.surfaceSecondary.opacity(0.5))
    }

    @State private var isNotesHovered = false
    private var notesNavItem: some View {
        Button {
            withAnimation(MadoTheme.Animation.quick) { showMemos.toggle() }
        } label: {
            HStack(spacing: MadoTheme.Spacing.xs) {
                Image(systemName: showMemos ? "doc.text.fill" : "doc.text")
                    .font(.system(size: 12))
                    .foregroundColor(showMemos ? MadoColors.accent : MadoColors.textSecondary)
                    .frame(width: 18)
                Text("Notes")
                    .font(MadoTheme.Font.captionMedium)
                    .foregroundColor(showMemos ? MadoColors.textPrimary : MadoColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, MadoTheme.Spacing.sm)
            .padding(.vertical, MadoTheme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .fill(showMemos ? MadoColors.accentLight : (isNotesHovered ? MadoColors.hoverBackground : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .onHover { isNotesHovered = $0 }
        .padding(.horizontal, MadoTheme.Spacing.xs)
    }

    @ViewBuilder
    private func sidebarItem(icon: String, label: String, section: TaskPanelSection, count: Int? = nil, hasChevron: Bool = false) -> some View {
        let isSelected = selectedSection == section
        let isHovered = hoveredSection == section
        Button {
            withAnimation(MadoTheme.Animation.quick) { selectedSection = section }
        } label: {
            HStack(spacing: MadoTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? MadoColors.accent : MadoColors.textSecondary)
                    .frame(width: 18)
                Text(label)
                    .font(MadoTheme.Font.captionMedium)
                    .foregroundColor(isSelected ? MadoColors.textPrimary : MadoColors.textSecondary)
                Spacer()
                if let count, count > 0 {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(MadoColors.textTertiary)
                }
                if hasChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(MadoColors.textTertiary)
                }
            }
            .padding(.horizontal, MadoTheme.Spacing.sm)
            .padding(.vertical, MadoTheme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .fill(isSelected ? MadoColors.accentLight : (isHovered ? MadoColors.hoverBackground : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .onHover { hoveredSection = $0 ? section : nil }
        .padding(.horizontal, MadoTheme.Spacing.xs)
    }

    @ViewBuilder
    private func projectNavItem(_ project: Project) -> some View {
        let isSelected: Bool = {
            if case .project(let id) = selectedSection { return id == project.id }
            return false
        }()
        let taskCount = viewModel.topLevelTasks.filter { !$0.isCompleted && $0.projectId == project.id }.count
        let isHovered = hoveredProjectId == project.id

        Button {
            withAnimation(MadoTheme.Animation.quick) { selectedSection = .project(project.id) }
        } label: {
            HStack(spacing: MadoTheme.Spacing.xs) {
                Text(String(project.name.prefix(1)).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(RoundedRectangle(cornerRadius: 4).fill(project.displayColor))
                Text(project.name)
                    .font(MadoTheme.Font.captionMedium)
                    .foregroundColor(isSelected ? MadoColors.textPrimary : MadoColors.textSecondary)
                    .lineLimit(1)
                Spacer()
                if taskCount > 0 {
                    Text("\(taskCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(MadoColors.textTertiary)
                }
            }
            .padding(.horizontal, MadoTheme.Spacing.sm)
            .padding(.vertical, MadoTheme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .fill(isSelected ? MadoColors.accentLight : (isHovered ? MadoColors.hoverBackground : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .onHover { hoveredProjectId = $0 ? project.id : nil }
        .padding(.horizontal, MadoTheme.Spacing.xs)
        .contextMenu {
            #if os(macOS)
            Button("Rename…") { renameProject(project) }
            #endif
            Menu("Color") {
                ForEach(ProjectColor.allCases, id: \.self) { c in
                    Button {
                        project.color = c
                        DataController.shared.save()
                        viewModel.loadProjects()
                    } label: {
                        Label(c.label, systemImage: project.color == c ? "checkmark.circle.fill" : "circle.fill")
                    }
                }
            }
            Divider()
            Button("Delete Project", role: .destructive) {
                viewModel.deleteProject(project)
                if case .project(let id) = selectedSection, id == project.id {
                    selectedSection = .inbox
                }
            }
        }
    }

    private var addProjectRow: some View {
        HStack(spacing: MadoTheme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 4)
                .fill(MadoColors.accent)
                .frame(width: 18, height: 18)
                .overlay(Image(systemName: "folder.fill").font(.system(size: 8)).foregroundColor(.white))
            TextField("Name", text: $newProjectName)
                .textFieldStyle(.plain)
                .font(MadoTheme.Font.caption)
                .onSubmit {
                    let name = newProjectName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { viewModel.addProject(name: name) }
                    newProjectName = ""
                    isAddingProject = false
                }
                #if os(macOS)
                .onExitCommand { newProjectName = ""; isAddingProject = false }
                #endif
        }
        .padding(.horizontal, MadoTheme.Spacing.sm)
        .padding(.vertical, MadoTheme.Spacing.xs)
        .padding(.horizontal, MadoTheme.Spacing.xs)
    }

    #if os(macOS)
    private func renameProject(_ project: Project) {
        let alert = NSAlert()
        alert.messageText = "Rename Project"
        alert.informativeText = "Enter a new name:"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = project.name
        alert.accessoryView = input
        if alert.runModal() == .alertFirstButtonReturn {
            let name = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { viewModel.renameProject(project, to: name) }
        }
    }
    #endif

    private var taskListArea: some View {
        VStack(spacing: 0) {
            taskListHeader
            Divider().foregroundColor(MadoColors.divider)
            if showFilterBar || isAnyFilterActive { filterBar }
            if selectedSection != .archive && selectedSection != .starred { quickAddRow }
            if filteredTasks.isEmpty {
                if isAnyFilterActive && !sectionTasks.isEmpty {
                    noFilterMatchState
                } else {
                    emptyState
                }
            } else {
                taskListContent
            }
            Spacer(minLength: 0)
        }
        .background(MadoColors.surface)
        #if os(macOS)
        .background {
            TaskKeyboardNav(
                tasks: allVisibleTasks,
                focusedId: focusedTaskId,
                detailTask: selectedTaskForDetail,
                setFocusedId: { focusedTaskId = $0 },
                setDetailTask: { selectedTaskForDetail = $0 },
                onToggle: { viewModel.toggleTask($0) },
                onDelete: { viewModel.deleteTask($0) },
                onUpdate: { viewModel.updateTask($0) },
                onFocusQuickAdd: { isQuickAddFocused = true }
            )
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
        #endif
        .popover(item: $selectedTaskForDetail, arrowEdge: .trailing) { task in
            TaskDetailPopover(task: task, viewModel: viewModel, onClose: { selectedTaskForDetail = nil })
        }
        .onChange(of: selectedSection) { focusedTaskId = nil }
    }

    @State private var isSyncHovered = false
    private var taskListHeader: some View {
        HStack(spacing: 10) {
            Text(sectionTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(MadoColors.textPrimary)
            Spacer()
            Button {
                withAnimation(MadoTheme.Animation.quick) { showFilterBar.toggle() }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isAnyFilterActive ? MadoColors.accent : (isFilterHovered ? MadoColors.textPrimary : MadoColors.textTertiary))
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(showFilterBar ? MadoColors.accentLight : (isFilterHovered ? MadoColors.surfaceSecondary : Color.clear))
                        )
                    if isAnyFilterActive {
                        Circle()
                            .fill(MadoColors.accent)
                            .frame(width: 6, height: 6)
                            .offset(x: -2, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)
            .onHover { isFilterHovered = $0 }
            Button { viewModel.loadAll() } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSyncHovered ? MadoColors.textPrimary : MadoColors.textTertiary)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSyncHovered ? MadoColors.surfaceSecondary : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isSyncHovered = $0 }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var sectionTitle: String {
        switch selectedSection {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .archive: return "Archive"
        case .starred: return "Starred"
        case .project(let id):
            return viewModel.projects.first { $0.id == id }?.name ?? "Project"
        }
    }

    private var quickAddRow: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(MadoColors.accent)
            TextField("Task title", text: $quickAddText)
                .textFieldStyle(.plain)
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textPrimary)
                .focused($isQuickAddFocused)
                .onSubmit {
                    let raw = quickAddText.trimmingCharacters(in: .whitespaces)
                    guard !raw.isEmpty else { return }
                    let parsed = NaturalDateParser.parse(raw)
                    let projectId: String? = {
                        if case .project(let id) = selectedSection { return id }
                        return nil
                    }()
                    viewModel.addTask(title: parsed.title, projectId: projectId, dueDate: parsed.dueDate)
                    quickAddText = ""
                }
                #if os(macOS)
                .onExitCommand {
                    quickAddText = ""
                    isQuickAddFocused = false
                }
                #endif
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
        .background(MadoColors.surface)
        .overlay(alignment: .bottom) { Divider().foregroundColor(MadoColors.divider) }
    }

    private var taskListContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !overdueTasks.isEmpty {
                        overdueHeader
                    }
                    ForEach(Array(allVisibleTasks.enumerated()), id: \.element.id) { idx, task in
                        TaskRow(
                            task: task,
                            viewModel: viewModel,
                            calendarVM: calendarVM,
                            subtasks: viewModel.subtasks(for: task),
                            isFocused: focusedTaskId == task.id,
                            onTap: {
                                focusedTaskId = task.id
                                selectedTaskForDetail = task
                            }
                        )
                        .id(task.id)
                    }
                }
            }
            .onChange(of: focusedTaskId) {
                if let id = focusedTaskId {
                    withAnimation(MadoTheme.Animation.quick) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private var overdueHeader: some View {
        HStack {
            Text("Overdue")
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(MadoColors.error)
            Text("\(overdueTasks.count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(MadoColors.error)
            Spacer()
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.xs)
    }

    private var emptyState: some View {
        VStack(spacing: MadoTheme.Spacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundColor(MadoColors.textTertiary.opacity(0.5))
            Text("No tasks")
                .font(MadoTheme.Font.caption)
                .foregroundColor(MadoColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MadoTheme.Spacing.xxxxl)
    }

    private var panelFooter: some View {
        Button {
            #if os(macOS)
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
            #endif
        } label: {
            HStack(spacing: MadoTheme.Spacing.sm) {
                if auth.status.isSignedIn {
                    Circle()
                        .fill(MadoColors.accent.opacity(0.15))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(String(auth.status.userName?.prefix(1) ?? "?"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(MadoColors.accent)
                        )
                    Text(auth.status.userName ?? "User")
                        .font(.system(size: 10))
                        .foregroundColor(MadoColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if sync.status.isSyncing {
                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                }
                Image(systemName: "gearshape").font(.system(size: 10)).foregroundColor(MadoColors.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .padding(.horizontal, MadoTheme.Spacing.sm)
        .padding(.vertical, MadoTheme.Spacing.xs)
    }

    // MARK: - Filter Bar

    @ViewBuilder
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                filterChip("P1", icon: "flag.fill", color: MadoColors.priorityHigh,
                           isActive: filterPriorities.contains(.high)) { togglePriority(.high) }
                filterChip("P2", icon: "flag.fill", color: MadoColors.priorityMedium,
                           isActive: filterPriorities.contains(.medium)) { togglePriority(.medium) }
                filterChip("P3", icon: "flag.fill", color: MadoColors.priorityLow,
                           isActive: filterPriorities.contains(.low)) { togglePriority(.low) }

                chipDivider

                filterChip("Scheduled", icon: "calendar", color: MadoColors.accent,
                           isActive: filterHasDate == true) { filterHasDate = filterHasDate == true ? nil : true }
                filterChip("No date", icon: "calendar.badge.minus", color: MadoColors.textSecondary,
                           isActive: filterHasDate == false) { filterHasDate = filterHasDate == false ? nil : false }

                if !viewModel.labels.isEmpty {
                    chipDivider
                    labelsFilterMenu
                }

                chipDivider
                sortFilterMenu

                Spacer(minLength: 0)

                if isAnyFilterActive {
                    Button { clearAllFilters() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(MadoColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear filters")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(MadoColors.surfaceSecondary.opacity(0.4))
    }

    private func filterChip(_ label: String, icon: String, color: Color, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isActive ? color : MadoColors.textTertiary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .fill(isActive ? color.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .stroke(isActive ? color.opacity(0.3) : MadoColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var chipDivider: some View {
        Rectangle()
            .fill(MadoColors.border)
            .frame(width: 1, height: 14)
            .padding(.horizontal, 2)
    }

    private var labelsFilterMenu: some View {
        Menu {
            ForEach(viewModel.labels, id: \.id) { label in
                Button {
                    if filterLabelIds.contains(label.id) {
                        filterLabelIds.remove(label.id)
                    } else {
                        filterLabelIds.insert(label.id)
                    }
                } label: {
                    HStack {
                        Text(label.name)
                        if filterLabelIds.contains(label.id) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "tag")
                    .font(.system(size: 8))
                Text(filterLabelIds.isEmpty ? "Labels" : "Labels (\(filterLabelIds.count))")
                    .font(.system(size: 10, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 6))
            }
            .foregroundColor(!filterLabelIds.isEmpty ? MadoColors.accent : MadoColors.textTertiary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .fill(!filterLabelIds.isEmpty ? MadoColors.accentLight : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .stroke(!filterLabelIds.isEmpty ? MadoColors.accent.opacity(0.3) : MadoColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var sortFilterMenu: some View {
        Menu {
            ForEach(TaskSortMode.allCases, id: \.self) { m in
                Button {
                    sortMode = m
                } label: {
                    HStack {
                        Text(m.rawValue)
                        if sortMode == m {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 8))
                Text(sortMode == .manual ? "Sort" : sortMode.rawValue)
                    .font(.system(size: 10, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 6))
            }
            .foregroundColor(sortMode != .manual ? MadoColors.accent : MadoColors.textTertiary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .fill(sortMode != .manual ? MadoColors.accentLight : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                    .stroke(sortMode != .manual ? MadoColors.accent.opacity(0.3) : MadoColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func togglePriority(_ p: TaskPriority) {
        if filterPriorities.contains(p) {
            filterPriorities.remove(p)
        } else {
            filterPriorities.insert(p)
        }
    }

    private func clearAllFilters() {
        filterPriorities.removeAll()
        filterHasDate = nil
        filterLabelIds.removeAll()
        sortMode = .manual
        withAnimation(MadoTheme.Animation.quick) { showFilterBar = false }
    }

    private var noFilterMatchState: some View {
        VStack(spacing: MadoTheme.Spacing.sm) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 28))
                .foregroundColor(MadoColors.textTertiary.opacity(0.5))
            Text("No matching tasks")
                .font(MadoTheme.Font.caption)
                .foregroundColor(MadoColors.textTertiary)
            Button("Clear filters") { clearAllFilters() }
                .font(MadoTheme.Font.caption)
                .foregroundColor(MadoColors.accent)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MadoTheme.Spacing.xxxxl)
    }

}

#if os(macOS)
// MARK: - Keyboard Navigation (AppKit NSEvent monitor)
private struct TaskKeyboardNav: NSViewRepresentable {
    let tasks: [MadoTask]
    let focusedId: String?
    let detailTask: MadoTask?
    let setFocusedId: (String?) -> Void
    let setDetailTask: (MadoTask?) -> Void
    let onToggle: (MadoTask) -> Void
    let onDelete: (MadoTask) -> Void
    let onUpdate: (MadoTask) -> Void
    var onFocusQuickAdd: (() -> Void)?
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let coord = context.coordinator
        coord.syncState(from: self)
        coord.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coord] event in
            guard let coord = coord else { return event }
            if let resp = event.window?.firstResponder, resp is NSTextView { return event }
            return coord.handleKey(event) ? nil : event
        }
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.syncState(from: self)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let m = coordinator.monitor { NSEvent.removeMonitor(m); coordinator.monitor = nil }
    }

    class Coordinator {
        var monitor: Any?
        var tasks: [MadoTask] = []
        var focusedId: String?
        var detailTask: MadoTask?
        var setFocusedId: ((String?) -> Void)?
        var setDetailTask: ((MadoTask?) -> Void)?
        var onToggle: ((MadoTask) -> Void)?
        var onDelete: ((MadoTask) -> Void)?
        var onUpdate: ((MadoTask) -> Void)?
        var onFocusQuickAdd: (() -> Void)?

        func syncState(from nav: TaskKeyboardNav) {
            tasks = nav.tasks
            focusedId = nav.focusedId
            detailTask = nav.detailTask
            setFocusedId = nav.setFocusedId
            setDetailTask = nav.setDetailTask
            onToggle = nav.onToggle
            onDelete = nav.onDelete
            onUpdate = nav.onUpdate
            onFocusQuickAdd = nav.onFocusQuickAdd
        }

        var focusedTask: MadoTask? {
            guard let id = focusedId else { return nil }
            return tasks.first { $0.id == id }
        }

        func handleKey(_ event: NSEvent) -> Bool {
            switch Int(event.keyCode) {
            case 126: moveFocus(-1); return true   // up
            case 125: moveFocus(1); return true    // down
            case 36:                                // Return
                if let t = focusedTask { setDetailTask?(t); return true }
                return false
            case 53:                                // Escape
                if detailTask != nil { setDetailTask?(nil); return true }
                if focusedId != nil { setFocusedId?(nil); return true }
                return false
            case 51:                                // Delete
                if let t = focusedTask { advanceAndAct(t) { onDelete?(t) }; return true }
                return false
            default: break
            }
            guard let chars = event.characters else { return false }
            guard !event.modifierFlags.contains(.command) else { return false }
            switch chars {
            case "e":
                if let t = focusedTask { advanceAndAct(t) { onToggle?(t) }; return true }
            case "1":
                if let t = focusedTask { t.priority = t.priority == .high ? .none : .high; onUpdate?(t); return true }
            case "2":
                if let t = focusedTask { t.priority = t.priority == .medium ? .none : .medium; onUpdate?(t); return true }
            case "3":
                if let t = focusedTask { t.priority = t.priority == .low ? .none : .low; onUpdate?(t); return true }
            case "0":
                if let t = focusedTask { t.priority = .none; onUpdate?(t); return true }
            case "s":
                if let t = focusedTask {
                    let today = Calendar.current.startOfDay(for: Date())
                    let isToday = t.dueDate.map { Calendar.current.isDate($0, inSameDayAs: today) } ?? false
                    t.dueDate = isToday ? nil : today
                    onUpdate?(t)
                    return true
                }
            case "S":
                if let t = focusedTask {
                    t.dueDate = nil
                    onUpdate?(t)
                    return true
                }
            case "/", "n":
                onFocusQuickAdd?()
                return true
            default: break
            }
            return false
        }

        func moveFocus(_ delta: Int) {
            guard !tasks.isEmpty else { return }
            if let id = focusedId, let idx = tasks.firstIndex(where: { $0.id == id }) {
                let newIdx = max(0, min(tasks.count - 1, idx + delta))
                setFocusedId?(tasks[newIdx].id)
            } else {
                setFocusedId?(delta > 0 ? tasks.first?.id : tasks.last?.id)
            }
        }

        func advanceAndAct(_ task: MadoTask, action: () -> Void) {
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                let nextId: String?
                if idx + 1 < tasks.count { nextId = tasks[idx + 1].id }
                else if idx > 0 { nextId = tasks[idx - 1].id }
                else { nextId = nil }
                action()
                setFocusedId?(nextId)
            }
        }
    }
}
#endif

private struct TaskRow: View {
    let task: MadoTask
    let viewModel: TodoViewModel
    var calendarVM: CalendarViewModel?
    var subtasks: [MadoTask] = []
    var isFocused: Bool = false
    var onTap: (() -> Void)?
    @State private var isHovered = false

    private var projectName: String? {
        guard let pid = task.projectId else { return nil }
        return viewModel.projects.first { $0.id == pid }?.name
    }

    private var projectColor: Color? {
        guard let pid = task.projectId else { return nil }
        return viewModel.projects.first { $0.id == pid }?.displayColor
    }

    private var dueDateText: String? {
        guard let due = task.dueDate else { return nil }
        let cal = Calendar.current
        let now = Date()
        if cal.isDateInToday(due) { return "Today" }
        if cal.isDateInYesterday(due) { return "Yesterday" }
        if cal.isDateInTomorrow(due) { return "Tomorrow" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: due)).day ?? 0
        if days < 0 { return "\(abs(days)) days ago" }
        if days > 0 && days < 7 { return "in \(days)d" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: due)
    }

    private var dueDateColor: Color {
        guard let due = task.dueDate else { return MadoColors.textTertiary }
        if due < Calendar.current.startOfDay(for: Date()) { return MadoColors.error }
        if Calendar.current.isDateInToday(due) { return MadoColors.accent }
        return MadoColors.textTertiary
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: MadoTheme.Spacing.sm) {
                Button { viewModel.toggleTask(task) } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundColor(task.isCompleted ? MadoColors.success : MadoColors.textPlaceholder)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textPrimary)
                        .lineLimit(1)
                    if let notes = task.notes, !notes.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 8))
                                .foregroundColor(MadoColors.textTertiary)
                            Text(notes)
                                .font(.system(size: 10))
                                .foregroundColor(MadoColors.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                HStack(spacing: MadoTheme.Spacing.xs) {
                    if let dateText = dueDateText {
                        Text(dateText)
                            .font(.system(size: 10))
                            .foregroundColor(dueDateColor)
                            .fixedSize()
                    }
                    if let name = projectName, let color = projectColor {
                        Text(name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(color)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    PriorityBadge(priority: task.priority)
                    if task.gmailMessageId != nil {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, MadoTheme.Spacing.md)
            .padding(.vertical, MadoTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isFocused ? MadoColors.accent.opacity(0.12) : (isHovered ? MadoColors.hoverBackground : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isFocused ? MadoColors.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    .padding(.horizontal, 2)
            )
            .onHover { isHovered = $0 }
            .draggable(TransferableTask(from: task))
            .onTapGesture { onTap?() }
            .contextMenu {
                Menu("Move to Project") {
                    Button("Inbox (No project)") { viewModel.moveTask(task, toProject: nil) }
                    Divider()
                    ForEach(viewModel.projects, id: \.id) { project in
                        Button(project.name) { viewModel.moveTask(task, toProject: project.id) }
                    }
                }
                if task.dueDate == nil || !Calendar.current.isDateInToday(task.dueDate!) {
                    Button("Plan Today") {
                        task.dueDate = Calendar.current.startOfDay(for: Date())
                        viewModel.updateTask(task)
                    }
                }
                if task.dueDate != nil {
                    Button("Clear Date") {
                        task.dueDate = nil
                        viewModel.updateTask(task)
                    }
                }
                Button("Add to Calendar") { addTaskToCalendar(task) }
                Divider()
                if task.priority == .none {
                    Button("Set High Priority") { task.priority = .high; viewModel.updateTask(task) }
                } else {
                    Button("Clear Priority") { task.priority = .none; viewModel.updateTask(task) }
                }
                Divider()
                Button("Delete", role: .destructive) { viewModel.deleteTask(task) }
            }

            if !subtasks.isEmpty {
                ForEach(subtasks, id: \.id) { sub in
                    HStack(spacing: MadoTheme.Spacing.sm) {
                        Button { viewModel.toggleTask(sub) } label: {
                            Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundColor(sub.isCompleted ? MadoColors.success : MadoColors.textPlaceholder)
                        }
                        .buttonStyle(.plain)
                        Text(sub.title)
                            .font(MadoTheme.Font.caption)
                            .foregroundColor(MadoColors.textSecondary)
                            .lineLimit(1)
                            .strikethrough(sub.isCompleted, color: MadoColors.textTertiary)
                        Spacer()
                    }
                    .padding(.leading, MadoTheme.Spacing.md + 27)
                    .padding(.trailing, MadoTheme.Spacing.md)
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private func addTaskToCalendar(_ task: MadoTask) {
        guard let vm = calendarVM else { return }
        // Snap to next 30-min slot
        let cal = Calendar.current
        let now = Date()
        let rawStart = task.dueDate ?? now
        let minute = cal.component(.minute, from: rawStart)
        let snapped = (minute / 30) * 30 + (minute % 30 > 0 ? 30 : 0)
        let start = cal.date(bySettingHour: cal.component(.hour, from: rawStart) + snapped / 60,
                               minute: snapped % 60, second: 0, of: rawStart) ?? rawStart
        // Just schedule the task (sets dueDate) — no event creation
        vm.scheduleTask(taskId: task.id, at: start)
    }
}

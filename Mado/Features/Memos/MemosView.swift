import SwiftUI

// MARK: - Notes ViewModel

enum MarkdownAction: Equatable {
    case none
    case togglePrefix(String)
    case wrapSelection(String)
}

@MainActor
@Observable
final class NotesViewModel {
    static let shared = NotesViewModel()

    var markdownAction: MarkdownAction = .none
    var fileManager = NoteFileManager.shared
    var selectedFile: NoteFileItem?
    var editorContent: String = ""
    var titleText: String = ""
    var searchText: String = ""
    var isCreatingFile = false
    var newFileName: String = ""
    var isCreatingFolder = false
    var newFolderName: String = ""
    var renamingItem: NoteFileItem?
    var renameText: String = ""

    private var saveTask: Task<Void, Never>?

    var displayItems: [NoteFileItem] {
        if searchText.isEmpty {
            return fileManager.items
        }
        return fileManager.search(query: searchText)
    }

    func selectFile(_ item: NoteFileItem) {
        saveCurrentFile()
        selectedFile = item
        titleText = item.displayName
        editorContent = fileManager.readFile(item)
    }

    func saveCurrentFile() {
        guard let file = selectedFile else { return }
        fileManager.writeFile(file, content: editorContent)
    }

    func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            saveCurrentFile()
        }
    }

    func commitTitleRename() {
        guard let file = selectedFile else { return }
        let newTitle = titleText.trimmingCharacters(in: .whitespaces)
        guard !newTitle.isEmpty, newTitle != file.displayName else { return }
        // Save content first, then rename file
        saveCurrentFile()
        fileManager.renameItem(file, to: newTitle)
        // Re-select the renamed file
        if let updated = fileManager.flatFiles().first(where: { $0.displayName == newTitle }) {
            selectedFile = updated
        }
    }

    func createNewFile() {
        let name = newFileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if let item = fileManager.createFile(name: name) {
            selectFile(item)
        }
        newFileName = ""
        isCreatingFile = false
    }

    func createNewFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        fileManager.createFolder(name: name)
        newFolderName = ""
        isCreatingFolder = false
    }

    func deleteItem(_ item: NoteFileItem) {
        if selectedFile?.id == item.id {
            selectedFile = nil
            editorContent = ""
            titleText = ""
        }
        fileManager.deleteItem(item)
    }

    func renameItem() {
        guard let item = renamingItem else { return }
        let name = renameText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        fileManager.renameItem(item, to: name)
        if selectedFile?.id == item.id {
            if let updated = fileManager.flatFiles().first(where: { $0.displayName == name }) {
                selectedFile = updated
                titleText = name
            }
        }
        renamingItem = nil
        renameText = ""
    }

    func createQuickNote() {
        let baseName = "Untitled"
        var name = baseName
        var counter = 2
        let existing = Set(fileManager.flatFiles().map { $0.displayName })
        while existing.contains(name) {
            name = "\(baseName) \(counter)"
            counter += 1
        }
        if let item = fileManager.createFile(name: name) {
            selectFile(item)
        }
    }

    func openTodayNote() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayName = formatter.string(from: Date())
        fileManager.loadFiles()
        if let existing = fileManager.flatFiles().first(where: { $0.displayName == todayName }) {
            selectFile(existing)
        } else if let created = fileManager.createFile(name: todayName) {
            selectFile(created)
        }
    }

    func deleteSelectedNote() {
        guard let file = selectedFile else { return }
        let files = fileManager.flatFiles()
        let idx = files.firstIndex(where: { $0.id == file.id })
        deleteItem(file)
        // Select adjacent note after deletion
        let updated = fileManager.flatFiles()
        if let idx = idx, !updated.isEmpty {
            selectFile(updated[min(idx, updated.count - 1)])
        }
    }

    func deselectNote() {
        saveCurrentFile()
        selectedFile = nil
        editorContent = ""
        titleText = ""
    }
}

// MARK: - macOS Notes View

#if os(macOS)
struct NotesView: View {
    @Bindable private var viewModel = NotesViewModel.shared
    @FocusState private var isEditorFocused: Bool
    @FocusState private var isTitleFocused: Bool
    @State private var keyMonitor: Any?

    var body: some View {
        HSplitView {
            notesSidebar
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            editorPane
                .frame(minWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MadoColors.surface)
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }

    // MARK: - Sidebar

    private var notesSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("Notes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MadoColors.textPrimary)
                Spacer()
                Menu {
                    Button("New Note") {
                        viewModel.isCreatingFile = true
                    }
                    Button("New Folder") {
                        viewModel.isCreatingFolder = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MadoColors.textTertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().foregroundColor(MadoColors.divider)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(MadoColors.textTertiary)
                TextField("Search notes...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(MadoTheme.Font.caption)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            Divider().foregroundColor(MadoColors.divider)

            // New file/folder input
            if viewModel.isCreatingFile {
                newItemRow(
                    placeholder: "Note title...",
                    text: $viewModel.newFileName,
                    icon: "doc.text",
                    onSubmit: { viewModel.createNewFile() },
                    onCancel: { viewModel.isCreatingFile = false; viewModel.newFileName = "" }
                )
            }
            if viewModel.isCreatingFolder {
                newItemRow(
                    placeholder: "Folder name...",
                    text: $viewModel.newFolderName,
                    icon: "folder",
                    onSubmit: { viewModel.createNewFolder() },
                    onCancel: { viewModel.isCreatingFolder = false; viewModel.newFolderName = "" }
                )
            }

            // File list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.displayItems) { item in
                        fileRow(item)
                    }
                }
            }

            Spacer(minLength: 0)

            // Vault path
            Divider().foregroundColor(MadoColors.divider)
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 9))
                    .foregroundColor(MadoColors.textTertiary)
                Text(viewModel.fileManager.vaultURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 9))
                    .foregroundColor(MadoColors.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(MadoColors.surfaceSecondary)
    }

    private func fileRow(_ item: NoteFileItem) -> AnyView {
        if item.isFolder {
            return AnyView(folderRow(item))
        } else {
            return AnyView(fileItemRow(item))
        }
    }

    @State private var expandedFolders: Set<String> = []

    private func folderRow(_ item: NoteFileItem) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if expandedFolders.contains(item.id) {
                        expandedFolders.remove(item.id)
                    } else {
                        expandedFolders.insert(item.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expandedFolders.contains(item.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(MadoColors.textTertiary)
                        .frame(width: 10)
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundColor(MadoColors.accent)
                    Text(item.name)
                        .font(MadoTheme.Font.caption)
                        .foregroundColor(MadoColors.textPrimary)
                    Spacer()
                    Text("\(item.children?.count ?? 0)")
                        .font(.system(size: 9))
                        .foregroundColor(MadoColors.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Delete Folder") { viewModel.deleteItem(item) }
            }

            if expandedFolders.contains(item.id), let children = item.children {
                ForEach(children) { child in
                    fileRow(child)
                        .padding(.leading, 16)
                }
            }
        }
    }

    @State private var hoveredFileId: String?

    private func fileItemRow(_ item: NoteFileItem) -> some View {
        let isSelected = viewModel.selectedFile?.id == item.id

        return Button {
            viewModel.selectFile(item)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? MadoColors.accent : MadoColors.textTertiary)

                    if viewModel.renamingItem?.id == item.id {
                        TextField("Name", text: $viewModel.renameText)
                            .textFieldStyle(.plain)
                            .font(MadoTheme.Font.caption)
                            .onSubmit { viewModel.renameItem() }
                            .onExitCommand { viewModel.renamingItem = nil }
                    } else {
                        Text(item.displayName)
                            .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                            .foregroundColor(isSelected ? MadoColors.accent : MadoColors.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                // Preview snippet — first line of content
                if !isSelected {
                    let preview = previewText(for: item)
                    if !preview.isEmpty {
                        Text(preview)
                            .font(.system(size: 10))
                            .foregroundColor(MadoColors.textTertiary)
                            .lineLimit(1)
                            .padding(.leading, 16)
                    }
                }

                Text(formatDate(item.modifiedDate))
                    .font(.system(size: 9))
                    .foregroundColor(MadoColors.textTertiary)
                    .padding(.leading, 16)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? MadoColors.accent.opacity(0.1) : (hoveredFileId == item.id ? MadoColors.hoverBackground : Color.clear))
                    .padding(.horizontal, 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredFileId = $0 ? item.id : nil }
        .contextMenu {
            Button("Rename") {
                viewModel.renamingItem = item
                viewModel.renameText = item.displayName
            }
            Divider()
            Button("Delete", role: .destructive) {
                viewModel.deleteItem(item)
            }
        }
    }

    private func previewText(for item: NoteFileItem) -> String {
        let content = viewModel.fileManager.readFile(item)
        let firstLine = content.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        // Skip markdown heading markers
        let cleaned = firstLine.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("#") {
            return String(cleaned.drop(while: { $0 == "#" || $0 == " " }))
        }
        return cleaned
    }

    private func newItemRow(placeholder: String, text: Binding<String>, icon: String, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(MadoColors.accent)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(MadoTheme.Font.caption)
                .onSubmit(onSubmit)
                .onExitCommand(perform: onCancel)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(MadoColors.accent.opacity(0.05))
    }

    // MARK: - Editor Pane (Obsidian-style: title + body)

    private var editorPane: some View {
        VStack(spacing: 0) {
            if viewModel.selectedFile != nil {
                noteEditor
            } else {
                emptyEditorState
            }
        }
    }

    private var noteEditor: some View {
        VStack(spacing: 0) {
            // Title field — large, prominent, editable
            TextField("Untitled", text: $viewModel.titleText)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(MadoColors.textPrimary)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 4)
                .onSubmit {
                    viewModel.commitTitleRename()
                    isEditorFocused = true
                }

            // Metadata line
            if let file = viewModel.selectedFile {
                HStack(spacing: 12) {
                    Text(formatDate(file.modifiedDate))
                    Text("·")
                    Text("\(wordCount(viewModel.editorContent)) words")
                    Text("·")
                    Text("\(viewModel.editorContent.count) chars")
                }
                .font(.system(size: 11))
                .foregroundColor(MadoColors.textTertiary)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            Divider()
                .foregroundColor(MadoColors.divider)
                .padding(.horizontal, 16)

            markdownToolbar

            MarkdownEditorView(
                text: $viewModel.editorContent,
                isFocused: $isEditorFocused,
                onChange: { viewModel.debouncedSave() }
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
            .background(MadoColors.surface)
        }
        .background(MadoColors.surface)
    }

    private var emptyEditorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(MadoColors.textTertiary.opacity(0.4))
            Text("Select a note or create a new one")
                .font(MadoTheme.Font.body)
                .foregroundColor(MadoColors.textTertiary)
            Button("New Note") {
                viewModel.isCreatingFile = true
            }
            .font(MadoTheme.Font.caption)
            .foregroundColor(MadoColors.accent)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MadoColors.surface)
    }

    private var markdownToolbar: some View {
        HStack(spacing: 2) {
            toolbarButton("H1", icon: nil) { NotesViewModel.shared.markdownAction = .togglePrefix("# ") }
            toolbarButton("H2", icon: nil) { NotesViewModel.shared.markdownAction = .togglePrefix("## ") }
            toolbarButton("H3", icon: nil) { NotesViewModel.shared.markdownAction = .togglePrefix("### ") }
            Divider().frame(height: 14).padding(.horizontal, 4)
            toolbarButton(nil, icon: "list.bullet") { NotesViewModel.shared.markdownAction = .togglePrefix("- ") }
            toolbarButton(nil, icon: "checklist") { NotesViewModel.shared.markdownAction = .togglePrefix("- [ ] ") }
            toolbarButton(nil, icon: "arrowtriangle.right.fill") { NotesViewModel.shared.markdownAction = .togglePrefix("▼ ") }
            Divider().frame(height: 14).padding(.horizontal, 4)
            toolbarButton(nil, icon: "bold") { NotesViewModel.shared.markdownAction = .wrapSelection("**") }
            toolbarButton(nil, icon: "italic") { NotesViewModel.shared.markdownAction = .wrapSelection("*") }
            toolbarButton(nil, icon: "chevron.left.forwardslash.chevron.right") { NotesViewModel.shared.markdownAction = .wrapSelection("`") }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 4)
    }

    private func toolbarButton(_ label: String?, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                } else if let label {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
            }
            .foregroundColor(MadoColors.textTertiary)
            .frame(width: 26, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        return fmt.string(from: date)
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    // MARK: - Keyboard Shortcuts

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [viewModel] event in
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])

            // ⌘N — New note
            if mods == .command, event.charactersIgnoringModifiers == "n" {
                viewModel.createQuickNote()
                return nil
            }

            // ⌘⌫ — Delete selected note (not when editing text)
            if mods == .command, event.keyCode == 51 {
                if let responder = event.window?.firstResponder,
                   responder is NSTextView || responder is NSTextField {
                    return event
                }
                viewModel.deleteSelectedNote()
                return nil
            }

            // Escape — Deselect note (let field editors handle it)
            if mods.isEmpty, event.keyCode == 53 {
                if let tv = event.window?.firstResponder as? NSTextView, tv.isFieldEditor {
                    return event
                }
                viewModel.deselectNote()
                return nil
            }

            // ⌘B — Bold
            if mods == .command, event.charactersIgnoringModifiers == "b" {
                if let tv = NotesView.focusedBodyEditor(in: event.window) {
                    NotesView.wrapSelection(in: tv, with: "**")
                    return nil
                }
                return event
            }

            // ⌘I — Italic
            if mods == .command, event.charactersIgnoringModifiers == "i" {
                if let tv = NotesView.focusedBodyEditor(in: event.window) {
                    NotesView.wrapSelection(in: tv, with: "*")
                    return nil
                }
                return event
            }

            // ⌘K — Link
            if mods == .command, event.charactersIgnoringModifiers == "k" {
                if let tv = NotesView.focusedBodyEditor(in: event.window) {
                    NotesView.insertLink(in: tv)
                    return nil
                }
                return event
            }

            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private static func focusedBodyEditor(in window: NSWindow?) -> NSTextView? {
        guard let tv = window?.firstResponder as? NSTextView, !tv.isFieldEditor else { return nil }
        return tv
    }

    private static func wrapSelection(in textView: NSTextView, with wrapper: String) {
        let range = textView.selectedRange()
        let text = textView.string as NSString
        let selected = range.length > 0 ? text.substring(with: range) : ""

        let replacement = "\(wrapper)\(selected)\(wrapper)"
        textView.insertText(replacement, replacementRange: range)

        if selected.isEmpty {
            // Place cursor between markers
            textView.setSelectedRange(NSRange(location: range.location + wrapper.count, length: 0))
        } else {
            // Re-select the wrapped text
            textView.setSelectedRange(NSRange(location: range.location + wrapper.count, length: selected.count))
        }
    }

    private static func insertLink(in textView: NSTextView) {
        let range = textView.selectedRange()
        let text = textView.string as NSString
        let selected = range.length > 0 ? text.substring(with: range) : ""

        if selected.isEmpty {
            textView.insertText("[](url)", replacementRange: range)
            textView.setSelectedRange(NSRange(location: range.location + 3, length: 3))
        } else {
            let replacement = "[\(selected)](url)"
            textView.insertText(replacement, replacementRange: range)
            textView.setSelectedRange(NSRange(location: range.location + selected.count + 3, length: 3))
        }
    }
}
#endif

#if os(iOS)
// MARK: - iOS Notes View

struct iOSNotesTab: View {
    private var viewModel = NotesViewModel.shared
    @State private var showNewNoteAlert = false
    @State private var showNewFolderAlert = false

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.searchText.isEmpty && viewModel.displayItems.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    ForEach(viewModel.displayItems) { item in
                        if item.isFolder {
                            iOSNoteFolderRow(item: item, viewModel: viewModel)
                        } else {
                            NavigationLink {
                                iOSNoteEditorView(item: item, viewModel: viewModel)
                            } label: {
                                iOSNoteFileRow(item: item)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Notes")
            .searchable(text: $viewModel.searchText, prompt: "Search notes...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showNewNoteAlert = true
                        } label: {
                            Label("New Note", systemImage: "doc.badge.plus")
                        }
                        Button {
                            showNewFolderAlert = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Note", isPresented: $showNewNoteAlert) {
                TextField("Title", text: $viewModel.newFileName)
                Button("Create") { viewModel.createNewFile() }
                Button("Cancel", role: .cancel) { viewModel.newFileName = "" }
            }
            .alert("New Folder", isPresented: $showNewFolderAlert) {
                TextField("Name", text: $viewModel.newFolderName)
                Button("Create") { viewModel.createNewFolder() }
                Button("Cancel", role: .cancel) { viewModel.newFolderName = "" }
            }
            .onAppear { viewModel.fileManager.loadFiles() }
        }
    }
}

private struct iOSNoteFileRow: View {
    let item: NoteFileItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 14))
                .foregroundColor(MadoColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textPrimary)
                    .lineLimit(1)
                Text(formatDate(item.modifiedDate))
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(MadoColors.textTertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        return fmt.string(from: date)
    }
}

private struct iOSNoteFolderRow: View {
    let item: NoteFileItem
    let viewModel: NotesViewModel

    var body: some View {
        DisclosureGroup {
            if let children = item.children {
                ForEach(children) { child in
                    if child.isFolder {
                        iOSNoteFolderRow(item: child, viewModel: viewModel)
                    } else {
                        NavigationLink {
                            iOSNoteEditorView(item: child, viewModel: viewModel)
                        } label: {
                            iOSNoteFileRow(item: child)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteItem(child)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundColor(MadoColors.accent)
                Text(item.name)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textPrimary)
                Spacer()
                Text("\(item.children?.count ?? 0)")
                    .font(MadoTheme.Font.tiny)
                    .foregroundColor(MadoColors.textTertiary)
            }
        }
    }
}

struct iOSNoteEditorView: View {
    let item: NoteFileItem
    let viewModel: NotesViewModel
    @State private var content: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $content)
            .font(.system(size: 15))
            .padding(.horizontal, 8)
            .focused($isFocused)
            .navigationTitle(item.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(content.count) chars")
                        .font(.caption)
                        .foregroundColor(MadoColors.textTertiary)
                }
            }
            .onAppear {
                content = viewModel.fileManager.readFile(item)
            }
            .onDisappear {
                viewModel.fileManager.writeFile(item, content: content)
                viewModel.fileManager.loadFiles()
            }
            .onChange(of: content) { _, _ in
                saveDebouncedTask?.cancel()
                saveDebouncedTask = Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    guard !Task.isCancelled else { return }
                    viewModel.fileManager.writeFile(item, content: content)
                }
            }
    }

    @State private var saveDebouncedTask: Task<Void, Never>?
}

#endif

import SwiftUI

@MainActor
final class QuickAddTaskWindow {
    static let shared = QuickAddTaskWindow()
    private var panel: NSPanel?
    weak var todoVM: TodoViewModel?
    weak var calendarVM: CalendarViewModel?

    private init() {}

    func toggle() {
        if let panel, panel.isVisible {
            panel.close()
            self.panel = nil
            return
        }
        show()
    }

    func show() {
        panel?.close()

        let panelWidth: CGFloat = 560
        let panelHeight: CGFloat = 200

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let content = QuickAddContent(
            onDismiss: { [weak self] in
                panel.close()
                self?.panel = nil
            },
            onCreateTask: { [weak self] title, date in
                if let vm = self?.todoVM {
                    vm.addTask(title: title, dueDate: date)
                } else {
                    let allTasks = (try? DataController.shared.fetchTasks()) ?? []
                    for t in allTasks { t.position += 1 }
                    let task = MadoTask(title: title, position: 0)
                    task.dueDate = date
                    DataController.shared.createTask(task)
                    SyncEngine.shared.schedulePush()
                }
            },
            onCreateEvent: { [weak self] parsed in
                guard let calVM = self?.calendarVM else { return }
                let cal = Calendar.current
                let start = parsed.startDate ?? Date()
                let endDate = parsed.endDate ?? cal.date(
                    byAdding: .minute,
                    value: AppSettings.shared.defaultEventDuration,
                    to: start
                ) ?? start
                calVM.createEventWithDetails(
                    title: parsed.title.isEmpty ? "New Event" : parsed.title,
                    startDate: start,
                    endDate: endDate,
                    location: nil,
                    notes: nil,
                    isAllDay: parsed.isAllDay,
                    guestEmails: nil,
                    addMeetLink: false
                )
            }
        )

        let hostingView = NSHostingView(rootView: content)
        panel.contentView = hostingView
        panel.center()

        if let screen = NSScreen.main {
            var frame = panel.frame
            frame.origin.y = screen.visibleFrame.midY + screen.visibleFrame.height * 0.15
            panel.setFrame(frame, display: true)
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        // Force focus after panel layout completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            panel.makeKey()
        }

        self.panel = panel
    }
}

// MARK: - Content View

private struct QuickAddContent: View {
    let onDismiss: () -> Void
    let onCreateTask: (String, Date?) -> Void
    let onCreateEvent: (ParsedEvent) -> Void

    @State private var title = ""
    @State private var selectedOption: Int = 0
    @State private var hoveredOption: Int? = nil
    @FocusState private var isFocused: Bool

    private var parsed: NaturalDateParser.Result {
        NaturalDateParser.parse(title.trimmingCharacters(in: .whitespaces))
    }

    private var eventParsed: ParsedEvent {
        NaturalLanguageParser.parse(title.trimmingCharacters(in: .whitespaces))
    }

    private var hasInput: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            inputRow

            if hasInput {
                Divider().foregroundColor(MadoColors.divider)
                createSection
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MadoColors.surface)
                .shadow(color: .black.opacity(0.15), radius: 20, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(MadoColors.border, lineWidth: 0.5)
                )
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(spacing: 10) {
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 5))

            ZStack(alignment: .leading) {
                // Hidden TextField — handles input, cursor, keyboard
                TextField("", text: $title)
                    .foregroundColor(.clear)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit { commitSelected() }
                    .onExitCommand { onDismiss() }
                    .onKeyPress(keys: [.downArrow, .upArrow]) { press in
                        if hasInput {
                            selectedOption = press.key == .downArrow ? 1 : 0
                        }
                        return .handled
                    }

                // Visible overlay with date/time highlighting
                if title.isEmpty {
                    Text("Try: 내일 3시 미팅, Review financials Monday 9am")
                        .font(.system(size: 14))
                        .foregroundColor(MadoColors.textPlaceholder)
                        .allowsHitTesting(false)
                } else {
                    highlightedText
                        .allowsHitTesting(false)
                }
            }

            Spacer(minLength: 0)

            if hasInput {
                Text("⏎")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(MadoColors.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: MadoTheme.Radius.xs)
                            .fill(MadoColors.surfaceSecondary)
                    )
            } else {
                HStack(spacing: 2) {
                    Text("⌘").font(.system(size: 10, weight: .medium, design: .rounded))
                    Text("0").font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundColor(MadoColors.textPlaceholder)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: MadoTheme.Radius.xs)
                        .fill(MadoColors.surfaceSecondary)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Create Section

    private var createSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Create")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(MadoColors.textTertiary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            createRow(
                icon: "checkmark.circle",
                iconColor: MadoColors.accent,
                label: "New Task",
                isSelected: selectedOption == 0,
                isHovered: hoveredOption == 0
            ) {
                selectedOption = 0
                commitSelected()
            }
            .onHover { hoveredOption = $0 ? 0 : nil }

            eventCreateRow(
                isSelected: selectedOption == 1,
                isHovered: hoveredOption == 1
            ) {
                selectedOption = 1
                commitSelected()
            }
            .onHover { hoveredOption = $0 ? 1 : nil }
        }
        .padding(.bottom, 8)
    }

    private func createRow(
        icon: String,
        iconColor: Color,
        label: String,
        isSelected: Bool,
        isHovered: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(iconColor)
                    .frame(width: 22)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MadoColors.textSecondary)

                Text("  ›  ")
                    .font(.system(size: 11))
                    .foregroundColor(MadoColors.textTertiary)

                Text(parsed.title)
                    .font(.system(size: 13))
                    .foregroundColor(MadoColors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let date = parsed.dueDate {
                    Text(formattedDate(date))
                        .font(.system(size: 12))
                        .foregroundColor(MadoColors.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? MadoColors.accentLight.opacity(0.5) : (isHovered ? MadoColors.hoverBackground : Color.clear))
            )
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    private func eventCreateRow(
        isSelected: Bool,
        isHovered: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let ep = eventParsed
        return Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundColor(MadoColors.priorityMedium)
                    .frame(width: 22)

                Text("New Event")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MadoColors.textSecondary)

                Text("  \u{203A}  ")
                    .font(.system(size: 11))
                    .foregroundColor(MadoColors.textTertiary)

                Text(ep.title.isEmpty ? parsed.title : ep.title)
                    .font(.system(size: 13))
                    .foregroundColor(MadoColors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let start = ep.startDate {
                    if ep.isAllDay {
                        Text(formattedDate(start) + " (all day)")
                            .font(.system(size: 12))
                            .foregroundColor(MadoColors.textTertiary)
                    } else {
                        Text(formattedDate(start))
                            .font(.system(size: 12))
                            .foregroundColor(MadoColors.textTertiary)
                    }
                } else if let date = parsed.dueDate {
                    Text(formattedDate(date))
                        .font(.system(size: 12))
                        .foregroundColor(MadoColors.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? MadoColors.accentLight.opacity(0.5) : (isHovered ? MadoColors.hoverBackground : Color.clear))
            )
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Highlighted Text

    private var highlightedText: Text {
        let ranges = NaturalDateParser.highlightRanges(title)
        guard !ranges.isEmpty else {
            return Text(title)
                .font(.system(size: 14))
                .foregroundColor(MadoColors.textPrimary)
        }

        var attr = AttributedString(title)
        attr.font = .system(size: 14)
        attr.foregroundColor = MadoColors.textPrimary

        for range in ranges {
            guard let start = AttributedString.Index(range.lowerBound, within: attr),
                  let end = AttributedString.Index(range.upperBound, within: attr) else { continue }
            attr[start..<end].foregroundColor = MadoColors.accent
            attr[start..<end].backgroundColor = MadoColors.accentLight
        }

        return Text(attr)
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        if cal.isDateInToday(date) {
            fmt.dateFormat = "'Today at' h:mm a"
        } else if cal.isDateInTomorrow(date) {
            fmt.dateFormat = "'Tomorrow at' h:mm a"
        } else {
            fmt.dateFormat = "EEE, MMM d 'at' h:mm a"
        }
        return fmt.string(from: date)
    }

    private func commitSelected() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if selectedOption == 0 {
            onCreateTask(parsed.title, parsed.dueDate)
        } else {
            // Use NaturalLanguageParser for events (supports endDate, isAllDay)
            let eventParsed = NaturalLanguageParser.parse(trimmed)
            onCreateEvent(eventParsed)
        }
        onDismiss()
    }
}

import SwiftUI

struct CommandBarView: View {
    @Binding var isPresented: Bool
    var calendarVM: CalendarViewModel
    var todoVM: TodoViewModel

    @State private var input = ""
    @FocusState private var isFocused: Bool

    private var parsed: ParsedEvent {
        NaturalLanguageParser.parse(input)
    }

    private var hasDate: Bool {
        parsed.startDate != nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                HStack(spacing: MadoTheme.Spacing.sm) {
                    Image(systemName: hasDate ? "calendar.badge.plus" : "plus.circle")
                        .font(.system(size: 16))
                        .foregroundColor(MadoColors.accent)

                    TextField("Create event or task...", text: $input)
                        .textFieldStyle(.plain)
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textPrimary)
                        .focused($isFocused)
                        .onSubmit { commit() }
                        #if os(macOS)
                        .onExitCommand { dismiss() }
                        #endif
                }
                .padding(.horizontal, MadoTheme.Spacing.lg)
                .padding(.vertical, MadoTheme.Spacing.md)

                if !input.isEmpty {
                    Divider().foregroundColor(MadoColors.divider)

                    previewRow
                        .padding(.horizontal, MadoTheme.Spacing.lg)
                        .padding(.vertical, MadoTheme.Spacing.sm)
                }
            }
            .frame(width: 480)
            .background(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.xl)
                    .fill(MadoColors.surface)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            )
            .padding(.top, 120)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear { isFocused = true }
    }

    private var previewRow: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            Image(systemName: hasDate ? "calendar" : "checkmark.circle")
                .font(.system(size: 12))
                .foregroundColor(MadoColors.textTertiary)

            Text(parsed.title.isEmpty ? "New Event" : parsed.title)
                .font(MadoTheme.Font.bodyMedium)
                .foregroundColor(MadoColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if let date = parsed.startDate {
                let fmt = DateFormatter()
                Text({
                    fmt.dateFormat = parsed.isAllDay ? "MMM d" : "MMM d, h:mm a"
                    return fmt.string(from: date)
                }())
                    .font(MadoTheme.Font.caption)
                    .foregroundColor(MadoColors.accent)
                    .padding(.horizontal, MadoTheme.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: MadoTheme.Radius.sm)
                            .fill(MadoColors.accentLight)
                    )
            } else {
                Text("Task")
                    .font(MadoTheme.Font.caption)
                    .foregroundColor(MadoColors.textTertiary)
            }
        }
    }

    private func commit() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { dismiss(); return }

        if let date = parsed.startDate {
            if parsed.isAllDay {
                // Create a task for all-day parsed items (matches Akiflow style)
                todoVM.addTask(title: parsed.title)
                if let lastTask = todoVM.tasks.last {
                    lastTask.dueDate = date
                    todoVM.updateTask(lastTask)
                }
            } else {
                calendarVM.createEventFromParsed(parsed)
            }
        } else {
            todoVM.addTask(title: trimmed)
        }
        dismiss()
    }

    private func dismiss() {
        withAnimation(MadoTheme.Animation.quick) {
            input = ""
            isPresented = false
        }
    }
}

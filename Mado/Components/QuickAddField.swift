import SwiftUI

struct QuickAddField: View {
    var placeholder: String = "Add a task..."
    var onSubmit: (String) -> Void

    @State private var text = ""
    @State private var isEditing = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: MadoTheme.Spacing.sm) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isEditing ? MadoColors.accent : MadoColors.textTertiary)

            if isEditing {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textPrimary)
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                    .onSubmit {
                        submitTask()
                    }
                    #if os(macOS)
                    .onExitCommand {
                        cancelEditing()
                    }
                    #endif
            } else {
                Text(placeholder)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textPlaceholder)

                Spacer()
            }
        }
        .padding(.horizontal, MadoTheme.Spacing.md)
        .padding(.vertical, MadoTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.md)
                .fill(isEditing ? MadoColors.surface : (isHovered ? MadoColors.hoverBackground : MadoColors.surfaceSecondary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MadoTheme.Radius.md)
                .stroke(isEditing ? MadoColors.accent : Color.clear, lineWidth: 1.5)
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            if !isEditing {
                isEditing = true
                isFocused = true
            }
        }
        .animation(MadoTheme.Animation.quick, value: isEditing)
    }

    private func submitTask() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelEditing()
            return
        }
        onSubmit(trimmed)
        text = ""
        // Keep editing mode for rapid entry
    }

    private func cancelEditing() {
        text = ""
        isEditing = false
        isFocused = false
    }
}

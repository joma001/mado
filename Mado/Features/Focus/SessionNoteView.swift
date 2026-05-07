import SwiftUI

struct SessionNoteView: View {
    let session: FocusSession
    let onDismiss: () -> Void
    let onSave: (String) -> Void

    @State private var noteText = ""

    var body: some View {
        VStack(spacing: MadoTheme.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(MadoColors.success)
                Text("Session Complete!")
                    .font(MadoTheme.Font.headline)
                    .foregroundColor(MadoColors.textPrimary)
                Spacer()
            }

            Text("What did you accomplish?")
                .font(MadoTheme.Font.callout)
                .foregroundColor(MadoColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextEditor(text: $noteText)
                .font(MadoTheme.Font.body)
                .frame(minHeight: 60, maxHeight: 100)
                .padding(MadoTheme.Spacing.xxs)
                .background(MadoColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: MadoTheme.Radius.md)
                        .stroke(MadoColors.border, lineWidth: 1)
                )

            HStack {
                Button("Skip") {
                    onDismiss()
                }
                .buttonStyle(MadoButtonStyle(variant: .ghost))

                Spacer()

                Button("Save") {
                    onSave(noteText)
                }
                .buttonStyle(MadoButtonStyle(variant: .primary))
            }
        }
        .padding(MadoTheme.Spacing.lg)
        .background(MadoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.lg))
        .shadow(color: MadoTheme.Shadow.popoverShadow.color,
                radius: MadoTheme.Shadow.popoverShadow.radius,
                x: MadoTheme.Shadow.popoverShadow.x,
                y: MadoTheme.Shadow.popoverShadow.y)
        .frame(maxWidth: 320)
    }
}

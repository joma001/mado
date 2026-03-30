#if os(macOS)
import SwiftUI
import AppKit

@MainActor
final class DetachedCalendarWindow {
    static let shared = DetachedCalendarWindow()
    private var panel: NSPanel?

    private init() {}

    var isVisible: Bool { panel?.isVisible ?? false }

    func show() {
        if let panel = panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let content = DetachedCalendarContentView {
            panel.close()
        }
        let hostingView = NSHostingView(rootView: content)
        panel.contentView = hostingView

        // Position near top-right of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            var frame = panel.frame
            frame.origin.x = screenFrame.maxX - frame.width - 20
            frame.origin.y = screenFrame.maxY - frame.height - 20
            panel.setFrame(frame, display: true)
        }

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close() {
        panel?.close()
        panel = nil
    }

    func toggle() {
        if isVisible {
            close()
        } else {
            show()
        }
    }
}

// MARK: - Detached Content View

private struct DetachedCalendarContentView: View {
    let onClose: () -> Void
    private let viewModel = MenuBarViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with close button
            HStack {
                Text("Calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MadoColors.textPrimary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(MadoColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MadoTheme.Spacing.lg)
            .padding(.top, MadoTheme.Spacing.md)
            .padding(.bottom, MadoTheme.Spacing.xs)

            MenuBarPopoverView()
        }
        .frame(width: 340, height: 520)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MadoColors.surface)
                .shadow(color: .black.opacity(0.15), radius: 20, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(MadoColors.border, lineWidth: 0.5)
                )
        )
    }
}
#endif

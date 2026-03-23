import SwiftUI

// MARK: - Mado Theme (Notion-inspired typography & spacing)
enum MadoTheme {

    // MARK: - Typography
    enum Font {
        static let largeTitle = SwiftUI.Font.system(size: 28, weight: .bold, design: .default)
        static let title = SwiftUI.Font.system(size: 20, weight: .semibold, design: .default)
        static let title2 = SwiftUI.Font.system(size: 17, weight: .semibold, design: .default)
        static let headline = SwiftUI.Font.system(size: 15, weight: .semibold, design: .default)
        static let body = SwiftUI.Font.system(size: 14, weight: .regular, design: .default)
        static let bodyMedium = SwiftUI.Font.system(size: 14, weight: .medium, design: .default)
        static let callout = SwiftUI.Font.system(size: 13, weight: .regular, design: .default)
        static let caption = SwiftUI.Font.system(size: 12, weight: .regular, design: .default)
        static let captionMedium = SwiftUI.Font.system(size: 12, weight: .medium, design: .default)
        static let tiny = SwiftUI.Font.system(size: 11, weight: .regular, design: .default)

        // Monospaced for timestamps
        static let timestamp = SwiftUI.Font.system(size: 11, weight: .medium, design: .monospaced)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let xxxxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum Radius {
        static let xs: CGFloat = 3
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
        static let full: CGFloat = 100
    }

    // MARK: - Shadows
    enum Shadow {
        static func sm() -> some View {
            Color.black.opacity(0.04)
        }

        static let cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            Color.black.opacity(0.08), 4, 0, 2
        )

        static let popoverShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            Color.black.opacity(0.15), 12, 0, 4
        )

        static let hoverShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            Color.black.opacity(0.06), 2, 0, 1
        )
    }

    // MARK: - Layout Constants
    enum Layout {
        static let sidebarWidth: CGFloat = 240
        static let menuBarPopoverWidth: CGFloat = 340
        static let menuBarPopoverHeight: CGFloat = 480
        static let mainWindowMinWidth: CGFloat = 900
        static let mainWindowMinHeight: CGFloat = 600
        static let calendarHourHeight: CGFloat = 60
        static let calendarTimeGutterWidth: CGFloat = 60
        static let todoRowHeight: CGFloat = 40
        static let eventBlockMinHeight: CGFloat = 24
    }

    // MARK: - Animation (Spring-based for natural feel)
    enum Animation {
        /// Snappy spring for hovers, selections, small toggles (replaces easeInOut 0.15)
        static let quick = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.9)
        /// Smooth spring for panel reveals, content transitions (replaces easeInOut 0.25)
        static let standard = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.86)
        /// Gentle spring for subtle state changes
        static let smooth = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.9)
        /// Quick exit for dismissals — no spring overshoot
        static let dismiss = SwiftUI.Animation.easeIn(duration: 0.15)
        /// Micro-bounce for press feedback
        static let micro = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.7)
    }
}

// MARK: - View Modifiers
struct MadoCardStyle: ViewModifier {
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(MadoColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.md)
                    .stroke(isHovered ? MadoColors.borderHover : MadoColors.border, lineWidth: 1)
            )
    }
}

struct MadoButtonStyle: ButtonStyle {
    var variant: Variant = .primary

    enum Variant {
        case primary, secondary, ghost
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MadoTheme.Font.bodyMedium)
            .padding(.horizontal, MadoTheme.Spacing.md)
            .padding(.vertical, MadoTheme.Spacing.sm)
            .foregroundColor(foregroundColor)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MadoTheme.Radius.md)
                    .stroke(borderColor, lineWidth: variant == .secondary ? 1 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(MadoTheme.Animation.micro, value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: return .white
        case .secondary: return MadoColors.textPrimary
        case .ghost: return MadoColors.textSecondary
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed ? MadoColors.accentHover : MadoColors.accent
        case .secondary:
            return isPressed ? MadoColors.pressedBackground : MadoColors.surface
        case .ghost:
            return isPressed ? MadoColors.pressedBackground : .clear
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary: return MadoColors.border
        default: return .clear
        }
    }
}

/// Subtle press feedback for plain-styled interactive elements
struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(MadoTheme.Animation.micro, value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func madoCard(isHovered: Bool = false) -> some View {
        modifier(MadoCardStyle(isHovered: isHovered))
    }
}

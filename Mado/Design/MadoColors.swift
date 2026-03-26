import SwiftUI

// MARK: - Adaptive Color Helper

private extension Color {
    /// Creates an adaptive color that switches between light and dark variants.
    #if os(macOS)
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark)
                : NSColor(light)
        })
    }
    #else
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
    #endif
}

// MARK: - Mado Color System
// Brand: Primary Navy #1A2744, Accent Orange #E8853A
enum MadoColors {
    // MARK: - Backgrounds
    static let background = Color(
        light: Color(hex: "FFFFFF"),
        dark: Color(hex: "121212")
    )
    static let surface = Color(
        light: .white,
        dark: Color(hex: "1E1E1E")
    )
    static let surfaceSecondary = Color(
        light: Color(hex: "F7F8FB"),
        dark: Color(hex: "2C2C2C")
    )
    static let surfaceTertiary = Color(
        light: Color(hex: "EDEFF5"),
        dark: Color(hex: "353535")
    )
    static let sidebar = Color(
        light: Color(hex: "F7F8FB"),
        dark: Color(hex: "1E1E1E")
    )

    // MARK: - Text
    static let textPrimary = Color(
        light: Color(hex: "1A1A1A"),
        dark: Color(hex: "ECECEC")
    )
    static let textSecondary = Color(
        light: Color(hex: "5A6478"),
        dark: Color(hex: "A0A0A0")
    )
    static let textTertiary = Color(
        light: Color(hex: "8A95A8"),
        dark: Color(hex: "6B6B6B")
    )
    static let textPlaceholder = Color(
        light: Color(hex: "B0B8C8"),
        dark: Color(hex: "555555")
    )

    // MARK: - Borders & Dividers
    static let border = Color(
        light: Color(hex: "E2E6EE"),
        dark: Color(hex: "3A3A3A")
    )
    static let borderHover = Color(
        light: Color(hex: "C8CED8"),
        dark: Color(hex: "505050")
    )
    static let divider = Color(
        light: Color(hex: "EEF0F5"),
        dark: Color(hex: "2A2A2A")
    )

    // MARK: - Priority Colors
    static let priorityHigh = Color(
        light: Color(hex: "EB5757"),
        dark: Color(hex: "EB5757")
    )
    static let priorityMedium = Color(
        light: Color(hex: "E8853A"),
        dark: Color(hex: "E8853A")
    )
    static let priorityLow = Color(
        light: Color(hex: "6FCF97"),
        dark: Color(hex: "6FCF97")
    )
    static let priorityNone = Color(
        light: Color(hex: "8A95A8"),
        dark: Color(hex: "6B6B6B")
    )

    // MARK: - Label Colors
    static let labelRed = Color(
        light: Color(hex: "FFE2DD"),
        dark: Color(hex: "5C2B2B")
    )
    static let labelOrange = Color(
        light: Color(hex: "FDECC8"),
        dark: Color(hex: "5C3D1A")
    )
    static let labelYellow = Color(
        light: Color(hex: "FBECB1"),
        dark: Color(hex: "4D3F1A")
    )
    static let labelGreen = Color(
        light: Color(hex: "DBEDDB"),
        dark: Color(hex: "2B4D2B")
    )
    static let labelBlue = Color(
        light: Color(hex: "D3E5EF"),
        dark: Color(hex: "1E3A4D")
    )
    static let labelPurple = Color(
        light: Color(hex: "E8DEEE"),
        dark: Color(hex: "3D2B4D")
    )
    static let labelPink = Color(
        light: Color(hex: "F5E0E9"),
        dark: Color(hex: "4D2B3A")
    )
    static let labelGray = Color(
        light: Color(hex: "E3E2E0"),
        dark: Color(hex: "3A3A3A")
    )

    static let labelRedText = Color(
        light: Color(hex: "93524F"),
        dark: Color(hex: "F0908D")
    )
    static let labelOrangeText = Color(
        light: Color(hex: "89642A"),
        dark: Color(hex: "E8B06A")
    )
    static let labelYellowText = Color(
        light: Color(hex: "7F6B2D"),
        dark: Color(hex: "E0C860")
    )
    static let labelGreenText = Color(
        light: Color(hex: "4B7B4B"),
        dark: Color(hex: "8FD08F")
    )
    static let labelBlueText = Color(
        light: Color(hex: "3B6C8C"),
        dark: Color(hex: "7BB8D8")
    )
    static let labelPurpleText = Color(
        light: Color(hex: "6B4C7C"),
        dark: Color(hex: "B88DD0")
    )
    static let labelPinkText = Color(
        light: Color(hex: "8C4B6B"),
        dark: Color(hex: "D08BAB")
    )
    static let labelGrayText = Color(
        light: Color(hex: "6B6B6A"),
        dark: Color(hex: "A0A0A0")
    )

    // MARK: - Accent (Mado Tangerine Orange)
    static let accent = Color(
        light: Color(hex: "E8853A"),
        dark: Color(hex: "E8853A")
    )
    static let accentHover = Color(
        light: Color(hex: "C4622A"),
        dark: Color(hex: "F09A55")
    )
    static let accentLight = Color(
        light: Color(hex: "FEF3EB"),
        dark: Color(hex: "3D2A1A")
    )

    // MARK: - Primary (Mado Navy)
    static let primary = Color(
        light: Color(hex: "1A2744"),
        dark: Color(hex: "8BA3CC")
    )
    static let primaryLight = Color(
        light: Color(hex: "2A3A5C"),
        dark: Color(hex: "A0B8D8")
    )

    // MARK: - Calendar Event Colors
    static let calendarDefault = Color(
        light: Color(hex: "E8853A"),
        dark: Color(hex: "E8853A")
    )
    static let calendarSecondary = Color(
        light: Color(hex: "1A2744"),
        dark: Color(hex: "8BA3CC")
    )
    static let calendarTertiary = Color(
        light: Color(hex: "C8944E"),
        dark: Color(hex: "C8944E")
    )

    // MARK: - States
    static let success = Color(
        light: Color(hex: "27AE60"),
        dark: Color(hex: "27AE60")
    )
    static let warning = Color(
        light: Color(hex: "E8853A"),
        dark: Color(hex: "E8853A")
    )
    static let error = Color(
        light: Color(hex: "EB5757"),
        dark: Color(hex: "EB5757")
    )
    static let info = Color(
        light: Color(hex: "1A2744"),
        dark: Color(hex: "8BA3CC")
    )

    // MARK: - Interactive
    static let hoverBackground = Color(
        light: Color(hex: "F0F2F7"),
        dark: Color(hex: "2C2C2C")
    )
    static let pressedBackground = Color(
        light: Color(hex: "E2E6EE"),
        dark: Color(hex: "353535")
    )
    static let selectedBackground = Color(
        light: Color(hex: "FEF3EB"),
        dark: Color(hex: "3D2A1A")
    )
    static let checkboxChecked = Color(
        light: Color(hex: "E8853A"),
        dark: Color(hex: "E8853A")
    )
    static let checkboxUnchecked = Color(
        light: Color(hex: "B0B8C8"),
        dark: Color(hex: "555555")
    )

    // MARK: - Semantic: On-Accent (text/icons placed on accent-colored backgrounds)
    /// Use for text/icons that sit on top of a filled accent or event-color background.
    /// Always white — independent of light/dark mode.
    static let onAccent = Color.white
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

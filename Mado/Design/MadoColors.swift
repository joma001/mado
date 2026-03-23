import SwiftUI

// MARK: - Mado Color System
// Brand: Primary Navy #1A2744, Accent Orange #E8853A
enum MadoColors {
    // MARK: - Backgrounds
    #if os(macOS)
    static let background = Color(nsColor: .windowBackgroundColor)
    #else
    static let background = Color(hex: "FFFFFF")
    #endif
    static let surface = Color.white
    static let surfaceSecondary = Color(hex: "F7F8FB")
    static let surfaceTertiary = Color(hex: "EDEFF5")
    static let sidebar = Color(hex: "F7F8FB")

    // MARK: - Text
    static let textPrimary = Color(hex: "1A1A1A")
    static let textSecondary = Color(hex: "5A6478")
    static let textTertiary = Color(hex: "8A95A8")
    static let textPlaceholder = Color(hex: "B0B8C8")

    // MARK: - Borders & Dividers
    static let border = Color(hex: "E2E6EE")
    static let borderHover = Color(hex: "C8CED8")
    static let divider = Color(hex: "EEF0F5")

    // MARK: - Priority Colors
    static let priorityHigh = Color(hex: "EB5757")
    static let priorityMedium = Color(hex: "E8853A")
    static let priorityLow = Color(hex: "6FCF97")
    static let priorityNone = Color(hex: "8A95A8")

    // MARK: - Label Colors
    static let labelRed = Color(hex: "FFE2DD")
    static let labelOrange = Color(hex: "FDECC8")
    static let labelYellow = Color(hex: "FBECB1")
    static let labelGreen = Color(hex: "DBEDDB")
    static let labelBlue = Color(hex: "D3E5EF")
    static let labelPurple = Color(hex: "E8DEEE")
    static let labelPink = Color(hex: "F5E0E9")
    static let labelGray = Color(hex: "E3E2E0")

    static let labelRedText = Color(hex: "93524F")
    static let labelOrangeText = Color(hex: "89642A")
    static let labelYellowText = Color(hex: "7F6B2D")
    static let labelGreenText = Color(hex: "4B7B4B")
    static let labelBlueText = Color(hex: "3B6C8C")
    static let labelPurpleText = Color(hex: "6B4C7C")
    static let labelPinkText = Color(hex: "8C4B6B")
    static let labelGrayText = Color(hex: "6B6B6A")

    // MARK: - Accent (Mado Tangerine Orange)
    static let accent = Color(hex: "E8853A")
    static let accentHover = Color(hex: "C4622A")
    static let accentLight = Color(hex: "FEF3EB")

    // MARK: - Primary (Mado Navy)
    static let primary = Color(hex: "1A2744")
    static let primaryLight = Color(hex: "2A3A5C")

    // MARK: - Calendar Event Colors
    static let calendarDefault = Color(hex: "E8853A")
    static let calendarSecondary = Color(hex: "1A2744")
    static let calendarTertiary = Color(hex: "C8944E")

    // MARK: - States
    static let success = Color(hex: "27AE60")
    static let warning = Color(hex: "E8853A")
    static let error = Color(hex: "EB5757")
    static let info = Color(hex: "1A2744")

    // MARK: - Interactive
    static let hoverBackground = Color(hex: "F0F2F7")
    static let pressedBackground = Color(hex: "E2E6EE")
    static let selectedBackground = Color(hex: "FEF3EB")
    static let checkboxChecked = Color(hex: "E8853A")
    static let checkboxUnchecked = Color(hex: "B0B8C8")
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

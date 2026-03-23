import Foundation
import SwiftData
import SwiftUI

@Model
final class UserCalendar {
    @Attribute(.unique) var id: String = UUID().uuidString
    var googleCalendarId: String = ""
    var name: String = ""
    var colorHex: String = "4A90D9"
    var isSelected: Bool = true
    var isPrimary: Bool = false
    var accessRole: String = "owner"
    var accountEmail: String = ""
    var notificationsEnabled: Bool = false
    var showInMenuBar: Bool = true
    var displayColor: Color {
        Color(hex: colorHex)
    }

    init(
        id: String = UUID().uuidString,
        googleCalendarId: String,
        name: String,
        colorHex: String = "4A90D9",
        isSelected: Bool = true,
        isPrimary: Bool = false,
        accessRole: String = "owner",
        accountEmail: String = "",
        notificationsEnabled: Bool = false,
        showInMenuBar: Bool = true
    ) {
        self.id = id
        self.googleCalendarId = googleCalendarId
        self.name = name
        self.colorHex = colorHex
        self.isSelected = isSelected
        self.isPrimary = isPrimary
        self.accessRole = accessRole
        self.accountEmail = accountEmail
        self.notificationsEnabled = notificationsEnabled
        self.showInMenuBar = showInMenuBar
    }
}

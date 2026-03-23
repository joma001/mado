import Foundation
#if os(macOS)
import ServiceManagement
#endif

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    // MARK: - Startup

    var launchAtLogin: Bool {
        didSet {
            #if os(macOS)
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
            #endif
        }
    }

    // MARK: - Display

    var defaultViewMode: String { didSet { defaults.set(defaultViewMode, forKey: "defaultViewMode") } }
    var startOfWeek: Int { didSet { defaults.set(startOfWeek, forKey: "startOfWeek") } }
    var use24HourTime: Bool { didSet { defaults.set(use24HourTime, forKey: "use24HourTime") } }
    var showWeekends: Bool { didSet { defaults.set(showWeekends, forKey: "showWeekends") } }
    var showWeekNumbers: Bool { didSet { defaults.set(showWeekNumbers, forKey: "showWeekNumbers") } }

    // MARK: - Calendar Defaults

    var defaultEventDuration: Int { didSet { defaults.set(defaultEventDuration, forKey: "defaultEventDuration") } }
    var defaultCalendarId: String { didSet { defaults.set(defaultCalendarId, forKey: "defaultCalendarId") } }
    var defaultReminderMinutes: Int { didSet { defaults.set(defaultReminderMinutes, forKey: "defaultReminderMinutes") } }

    // MARK: - Working Hours

    var workingHoursStart: Int { didSet { defaults.set(workingHoursStart, forKey: "workingHoursStart") } }
    var workingHoursEnd: Int { didSet { defaults.set(workingHoursEnd, forKey: "workingHoursEnd") } }

    // MARK: - Events

    var showDeclinedEvents: Bool { didSet { defaults.set(showDeclinedEvents, forKey: "showDeclinedEvents") } }

    // MARK: - Sync

    var syncIntervalMinutes: Double { didSet { defaults.set(syncIntervalMinutes, forKey: "syncIntervalMinutes") } }
    var gmailSyncEnabled: Bool { didSet { defaults.set(gmailSyncEnabled, forKey: "gmailSyncEnabled") } }
    var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") } }
    var morningBriefEnabled: Bool { didSet { defaults.set(morningBriefEnabled, forKey: "morningBriefEnabled") } }

    // MARK: - Menu Bar

    var menuBarDisplayMode: String { didSet { defaults.set(menuBarDisplayMode, forKey: "menuBarDisplayMode") } }

    // MARK: - Helpers

    func formatHour(_ hour: Int) -> String {
        if use24HourTime {
            return String(format: "%02d:00", hour)
        }
        if hour == 0 { return "12 am" }
        if hour < 12 { return "\(hour) am" }
        if hour == 12 { return "12 pm" }
        return "\(hour - 12) pm"
    }

    // MARK: - Init

    private init() {
        #if os(macOS)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        #else
        launchAtLogin = false
        #endif
        defaultViewMode = defaults.string(forKey: "defaultViewMode") ?? "weekly"
        startOfWeek = defaults.object(forKey: "startOfWeek") as? Int ?? 2
        use24HourTime = defaults.bool(forKey: "use24HourTime")
        showWeekends = defaults.object(forKey: "showWeekends") as? Bool ?? true
        showWeekNumbers = defaults.bool(forKey: "showWeekNumbers")
        defaultEventDuration = defaults.object(forKey: "defaultEventDuration") as? Int ?? 60
        defaultCalendarId = defaults.string(forKey: "defaultCalendarId") ?? ""
        defaultReminderMinutes = defaults.object(forKey: "defaultReminderMinutes") as? Int ?? 10
        workingHoursStart = defaults.object(forKey: "workingHoursStart") as? Int ?? 9
        workingHoursEnd = defaults.object(forKey: "workingHoursEnd") as? Int ?? 18
        showDeclinedEvents = defaults.bool(forKey: "showDeclinedEvents")
        syncIntervalMinutes = defaults.object(forKey: "syncIntervalMinutes") as? Double ?? 5.0
        menuBarDisplayMode = defaults.string(forKey: "menuBarDisplayMode") ?? "nextEvent"
        gmailSyncEnabled = defaults.object(forKey: "gmailSyncEnabled") as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        morningBriefEnabled = defaults.object(forKey: "morningBriefEnabled") as? Bool ?? true
    }
}

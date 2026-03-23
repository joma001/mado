import Foundation

/// Cached DateFormatter instances to avoid repeated allocation in SwiftUI computed properties.
/// All formatters are accessed from @MainActor / main-thread contexts.
enum DateFormatters {
    /// "MMMM yyyy" — e.g. "March 2026"
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// "EEE, MMM d" — e.g. "Wed, Mar 4"
    static let shortDayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    /// "EEE, MMM d, h:mm a" — e.g. "Wed, Mar 4, 3:30 PM"
    static let dayDateTimeComma: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d, h:mm a"
        return f
    }()

    /// "EEE, MMM d h:mm a" — e.g. "Wed, Mar 4 3:30 PM"
    static let dayDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d h:mm a"
        return f
    }()

    /// "h:mm a" — e.g. "3:30 PM"
    static let time12h: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    /// "HH:mm" — e.g. "15:30"
    static let time24h: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// "EEEE, MMMM d" — e.g. "Wednesday, March 4"
    static let fullWeekdayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    /// "MMM d" — e.g. "Mar 4"
    static let shortMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// Returns the appropriate time formatter based on the 24-hour preference.
    static func time(use24Hour: Bool) -> DateFormatter {
        use24Hour ? time24h : time12h
    }
}

import Foundation

/// Shared date-parsing constants used by both NaturalDateParser (tasks) and NaturalLanguageParser (events).
enum DateParsingCommon {
    /// Korean single-character weekday → Calendar weekday (1=Sun … 7=Sat)
    static let koreanWeekdayMap: [String: Int] = [
        "일": 1, "월": 2, "화": 3, "수": 4, "목": 5, "금": 6, "토": 7,
    ]

    /// English day name/abbreviation → Calendar weekday (1=Sun … 7=Sat)
    static let englishWeekdayMap: [String: Int] = [
        "sunday": 1, "sun": 1,
        "monday": 2, "mon": 2,
        "tuesday": 3, "tue": 3, "tues": 3,
        "wednesday": 4, "wed": 4,
        "thursday": 5, "thu": 5, "thurs": 5, "thur": 5,
        "friday": 6, "fri": 6,
        "saturday": 7, "sat": 7,
    ]

    /// Korean relative day keywords, ordered longest-first for greedy matching.
    static let koreanRelativeDays: [(keyword: String, offset: Int)] = [
        ("글피", 3), ("모레", 2), ("내일", 1), ("오늘", 0),
    ]
}

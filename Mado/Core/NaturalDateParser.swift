import Foundation

/// Parses natural language date/time from task input text.
/// Supports Korean (내일 3시 미팅) and English (Review financials Monday 9am).
struct NaturalDateParser {

    struct Result {
        let title: String
        let dueDate: Date?
    }

    private static let cal = Calendar.current

    private static let koreanDayMap = DateParsingCommon.koreanWeekdayMap
    private static let englishDayMap = DateParsingCommon.englishWeekdayMap

    // MARK: - Public API

    static func parse(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Result(title: trimmed, dueDate: nil) }

        var remaining = trimmed
        var dateComponent: Date?
        var hour: Int?
        var minute: Int?

        // --- Korean time extraction (must run before date to avoid partial matches) ---

        // 오전/오후 X시 Y분
        if let match = remaining.firstMatch(
            #"(오전|오후)\s*(\d{1,2})시\s*(\d{1,2})분"#
        ) {
            let ampm = match.group(1)!
            var h = Int(match.group(2)!)!
            let m = Int(match.group(3)!)!
            if ampm == "오후" && h < 12 { h += 12 }
            if ampm == "오전" && h == 12 { h = 0 }
            hour = h; minute = m
            remaining = remaining.removing(match)
        }
        // 오전/오후 X시 반
        else if let match = remaining.firstMatch(
            #"(오전|오후)\s*(\d{1,2})시\s*반"#
        ) {
            let ampm = match.group(1)!
            var h = Int(match.group(2)!)!
            if ampm == "오후" && h < 12 { h += 12 }
            if ampm == "오전" && h == 12 { h = 0 }
            hour = h; minute = 30
            remaining = remaining.removing(match)
        }
        // 오전/오후 X시
        else if let match = remaining.firstMatch(
            #"(오전|오후)\s*(\d{1,2})시"#
        ) {
            let ampm = match.group(1)!
            var h = Int(match.group(2)!)!
            if ampm == "오후" && h < 12 { h += 12 }
            if ampm == "오전" && h == 12 { h = 0 }
            hour = h; minute = 0
            remaining = remaining.removing(match)
        }
        // X시 Y분 (no AM/PM — assume contextual, default 24h)
        else if let match = remaining.firstMatch(
            #"(\d{1,2})시\s*(\d{1,2})분"#
        ) {
            hour = Int(match.group(1)!)!
            minute = Int(match.group(2)!)!
            remaining = remaining.removing(match)
        }
        // X시 반
        else if let match = remaining.firstMatch(
            #"(\d{1,2})시\s*반"#
        ) {
            hour = Int(match.group(1)!)!
            minute = 30
            remaining = remaining.removing(match)
        }
        // X시
        else if let match = remaining.firstMatch(
            #"(\d{1,2})시"#
        ) {
            hour = Int(match.group(1)!)!
            minute = 0
            remaining = remaining.removing(match)
        }

        // --- English time extraction ---
        // 3:30pm, 3:30 pm
        if hour == nil, let match = remaining.firstMatch(
            #"(\d{1,2}):(\d{2})\s*(am|pm|AM|PM)"#
        ) {
            var h = Int(match.group(1)!)!
            let m = Int(match.group(2)!)!
            let ampm = match.group(3)!.lowercased()
            if ampm == "pm" && h < 12 { h += 12 }
            if ampm == "am" && h == 12 { h = 0 }
            hour = h; minute = m
            remaining = remaining.removing(match)
        }
        // 9am, 9 am, 3pm, 3 pm
        else if hour == nil, let match = remaining.firstMatch(
            #"(\d{1,2})\s*(am|pm|AM|PM)"#
        ) {
            var h = Int(match.group(1)!)!
            let ampm = match.group(2)!.lowercased()
            if ampm == "pm" && h < 12 { h += 12 }
            if ampm == "am" && h == 12 { h = 0 }
            hour = h; minute = 0
            remaining = remaining.removing(match)
        }

        // --- Korean date extraction ---

        let now = Date()

        // 오늘
        if let match = remaining.firstMatch(#"오늘"#) {
            dateComponent = now
            remaining = remaining.removing(match)
        }
        // 내일
        else if let match = remaining.firstMatch(#"내일"#) {
            dateComponent = cal.date(byAdding: .day, value: 1, to: now)
            remaining = remaining.removing(match)
        }
        // 모레
        else if let match = remaining.firstMatch(#"모레"#) {
            dateComponent = cal.date(byAdding: .day, value: 2, to: now)
            remaining = remaining.removing(match)
        }
        // 글피
        else if let match = remaining.firstMatch(#"글피"#) {
            dateComponent = cal.date(byAdding: .day, value: 3, to: now)
            remaining = remaining.removing(match)
        }
        // 다음주 / 다음 + 요일
        else if let match = remaining.firstMatch(
            #"(다음주|다음)\s*(월|화|수|목|금|토|일)(?:요일)?"#
        ) {
            if let weekday = koreanDayMap[match.group(2)!] {
                dateComponent = nextWeekday(weekday, from: now, forceNextWeek: true)
            }
            remaining = remaining.removing(match)
        }
        // 이번주 / 이번 + 요일
        else if let match = remaining.firstMatch(
            #"(이번주|이번)\s*(월|화|수|목|금|토|일)(?:요일)?"#
        ) {
            if let weekday = koreanDayMap[match.group(2)!] {
                dateComponent = nextWeekday(weekday, from: now, forceNextWeek: false)
            }
            remaining = remaining.removing(match)
        }
        // 월요일, 화요일... (bare day of week — next occurrence)
        else if let match = remaining.firstMatch(
            #"(월|화|수|목|금|토|일)요일"#
        ) {
            if let weekday = koreanDayMap[match.group(1)!] {
                dateComponent = nextWeekday(weekday, from: now, forceNextWeek: false)
            }
            remaining = remaining.removing(match)
        }

        // --- English date extraction ---

        if dateComponent == nil {
            // today
            if let match = remaining.firstMatch(#"(?i)\btoday\b"#) {
                dateComponent = now
                remaining = remaining.removing(match)
            }
            // tomorrow
            else if let match = remaining.firstMatch(#"(?i)\btomorrow\b"#) {
                dateComponent = cal.date(byAdding: .day, value: 1, to: now)
                remaining = remaining.removing(match)
            }
            // next + day
            else if let match = remaining.firstMatch(
                #"(?i)\bnext\s+(sunday|sun|monday|mon|tuesday|tue|tues|wednesday|wed|thursday|thu|thurs?|friday|fri|saturday|sat)\b"#
            ) {
                let dayStr = match.group(1)!.lowercased()
                if let weekday = englishDayMap[dayStr] {
                    dateComponent = nextWeekday(weekday, from: now, forceNextWeek: true)
                }
                remaining = remaining.removing(match)
            }
            // this + day
            else if let match = remaining.firstMatch(
                #"(?i)\bthis\s+(sunday|sun|monday|mon|tuesday|tue|tues|wednesday|wed|thursday|thu|thurs?|friday|fri|saturday|sat)\b"#
            ) {
                let dayStr = match.group(1)!.lowercased()
                if let weekday = englishDayMap[dayStr] {
                    dateComponent = nextWeekday(weekday, from: now, forceNextWeek: false)
                }
                remaining = remaining.removing(match)
            }
            // bare day name (Monday, Fri, etc.)
            else if let match = remaining.firstMatch(
                #"(?i)\b(sunday|sun|monday|mon|tuesday|tue|tues|wednesday|wed|thursday|thu|thurs?|friday|fri|saturday|sat)\b"#
            ) {
                let dayStr = match.group(1)!.lowercased()
                if let weekday = englishDayMap[dayStr] {
                    dateComponent = nextWeekday(weekday, from: now, forceNextWeek: false)
                }
                remaining = remaining.removing(match)
            }
        }

        // --- Combine date + time ---

        var dueDate: Date?

        if dateComponent != nil || hour != nil {
            let baseDate = dateComponent ?? now
            let baseDay = cal.startOfDay(for: baseDate)

            if let h = hour {
                let m = minute ?? 0
                dueDate = cal.date(bySettingHour: h, minute: m, second: 0, of: baseDay)
            } else {
                // Date but no time — default to 9:00 AM
                dueDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: baseDay)
            }
        }

        // --- Clean title ---
        let cleanTitle = remaining
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return Result(
            title: cleanTitle.isEmpty ? input.trimmingCharacters(in: .whitespaces) : cleanTitle,
            dueDate: dueDate
        )
    }

    // MARK: - Highlight Ranges

    /// Returns ranges of date/time tokens in the original input string for inline highlighting.
    static func highlightRanges(_ input: String) -> [Range<String.Index>] {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []

        // Time patterns (first match wins)
        let timePatterns = [
            #"(오전|오후)\s*(\d{1,2})시\s*(\d{1,2})분"#,
            #"(오전|오후)\s*(\d{1,2})시\s*반"#,
            #"(오전|오후)\s*(\d{1,2})시"#,
            #"(\d{1,2})시\s*(\d{1,2})분"#,
            #"(\d{1,2})시\s*반"#,
            #"(\d{1,2})시"#,
            #"(\d{1,2}):(\d{2})\s*(am|pm|AM|PM)"#,
            #"(\d{1,2})\s*(am|pm|AM|PM)"#,
        ]
        for pattern in timePatterns {
            if let match = input.firstMatch(pattern) {
                ranges.append(match.range)
                break
            }
        }

        // Date patterns (first match wins)
        let datePatterns = [
            #"오늘"#, #"내일"#, #"모레"#, #"글피"#,
            #"(다음주|다음)\s*(월|화|수|목|금|토|일)(?:요일)?"#,
            #"(이번주|이번)\s*(월|화|수|목|금|토|일)(?:요일)?"#,
            #"(월|화|수|목|금|토|일)요일"#,
            #"(?i)\btoday\b"#,
            #"(?i)\btomorrow\b"#,
            #"(?i)\bnext\s+(sunday|sun|monday|mon|tuesday|tue|tues|wednesday|wed|thursday|thu|thurs?|friday|fri|saturday|sat)\b"#,
            #"(?i)\bthis\s+(sunday|sun|monday|mon|tuesday|tue|tues|wednesday|wed|thursday|thu|thurs?|friday|fri|saturday|sat)\b"#,
            #"(?i)\b(sunday|sun|monday|mon|tuesday|tue|tues|wednesday|wed|thursday|thu|thurs?|friday|fri|saturday|sat)\b"#,
        ]
        for pattern in datePatterns {
            if let match = input.firstMatch(pattern) {
                if !ranges.contains(where: { $0.overlaps(match.range) }) {
                    ranges.append(match.range)
                }
                break
            }
        }

        guard !ranges.isEmpty else { return [] }

        // Merge adjacent ranges (separated by at most 1 space) into one highlight
        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }
        var merged: [Range<String.Index>] = [sorted[0]]

        for i in 1..<sorted.count {
            let current = sorted[i]
            let last = merged[merged.count - 1]
            let gap = input[last.upperBound..<current.lowerBound]
            if gap.allSatisfy({ $0.isWhitespace }) && gap.count <= 1 {
                merged[merged.count - 1] = last.lowerBound..<current.upperBound
            } else {
                merged.append(current)
            }
        }

        return merged
    }

    // MARK: - Helpers

    /// Finds the next occurrence of a given weekday (1=Sun, 7=Sat).
    /// If forceNextWeek, always goes to next week even if today matches.
    private static func nextWeekday(_ target: Int, from date: Date, forceNextWeek: Bool) -> Date {
        let current = cal.component(.weekday, from: date)
        var daysAhead = target - current
        if daysAhead < 0 { daysAhead += 7 }
        if daysAhead == 0 {
            daysAhead = forceNextWeek ? 7 : 0
        }
        if forceNextWeek && daysAhead < 7 { daysAhead += 7 }
        return cal.date(byAdding: .day, value: daysAhead, to: date) ?? date
    }
}

// MARK: - Regex Helpers

private struct RegexMatch {
    let range: Range<String.Index>
    let nsResult: NSTextCheckingResult
    let source: String

    func group(_ index: Int) -> String? {
        let r = nsResult.range(at: index)
        guard r.location != NSNotFound else { return nil }
        return (source as NSString).substring(with: r)
    }
}

private extension String {
    func firstMatch(_ pattern: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(startIndex..., in: self)
        guard let result = regex.firstMatch(in: self, range: nsRange) else { return nil }
        guard let range = Range(result.range, in: self) else { return nil }
        return RegexMatch(range: range, nsResult: result, source: self)
    }

    func removing(_ match: RegexMatch) -> String {
        var s = self
        s.removeSubrange(match.range)
        return s
    }
}

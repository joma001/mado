import Foundation

struct ParsedEvent {
    let title: String
    let startDate: Date?
    let endDate: Date?
    let isAllDay: Bool
}

enum NaturalLanguageParser {

    static func parse(_ input: String) -> ParsedEvent {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedEvent(title: "", startDate: nil, endDate: nil, isAllDay: false)
        }

        // Try Korean patterns first
        if let result = parseKorean(trimmed) {
            return result
        }

        // Fall back to NSDataDetector for English / system locale
        return parseWithDetector(trimmed)
    }

    // MARK: - Korean Date/Time Parser

    private static func parseKorean(_ input: String) -> ParsedEvent? {
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)

        var remaining = input
        var baseDate: Date?
        var hour: Int?
        var minute: Int = 0
        var isPM: Bool?
        var foundDate = false
        var foundTime = false

        // --- "다음주 X요일" ---
        if let regex = try? NSRegularExpression(pattern: "다음\\s*주?\\s*(월|화|수|목|금|토|일)요일?"),
           let match = regex.firstMatch(in: remaining, range: nsRange(remaining)),
           let dayRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining),
           let wd = koreanWeekday(String(remaining[dayRange])) {
            baseDate = targetWeekday(wd, weekOffset: 1, from: today)
            remaining.removeSubrange(fullRange)
            foundDate = true
        }

        // --- "이번주 X요일" ---
        if !foundDate,
           let regex = try? NSRegularExpression(pattern: "이번\\s*주?\\s*(월|화|수|목|금|토|일)요일?"),
           let match = regex.firstMatch(in: remaining, range: nsRange(remaining)),
           let dayRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining),
           let wd = koreanWeekday(String(remaining[dayRange])) {
            baseDate = targetWeekday(wd, weekOffset: 0, from: today)
            remaining.removeSubrange(fullRange)
            foundDate = true
        }

        // --- "X요일" (next occurrence) ---
        if !foundDate,
           let regex = try? NSRegularExpression(pattern: "(월|화|수|목|금|토|일)요일"),
           let match = regex.firstMatch(in: remaining, range: nsRange(remaining)),
           let dayRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining),
           let wd = koreanWeekday(String(remaining[dayRange])) {
            baseDate = nextOccurrence(of: wd, after: today)
            remaining.removeSubrange(fullRange)
            foundDate = true
        }

        // --- "다음달 N일" ---
        if !foundDate,
           let regex = try? NSRegularExpression(pattern: "다음\\s*달\\s*(\\d{1,2})\\s*일?"),
           let match = regex.firstMatch(in: remaining, range: nsRange(remaining)),
           let dayRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining),
           let day = Int(remaining[dayRange]),
           let nextMonth = cal.date(byAdding: .month, value: 1, to: today) {
            var comps = cal.dateComponents([.year, .month], from: nextMonth)
            comps.day = day
            baseDate = cal.date(from: comps)
            remaining.removeSubrange(fullRange)
            foundDate = true
        }

        // --- "N월 N일" (absolute date) ---
        if !foundDate,
           let regex = try? NSRegularExpression(pattern: "(\\d{1,2})\\s*월\\s*(\\d{1,2})\\s*일"),
           let match = regex.firstMatch(in: remaining, range: nsRange(remaining)),
           let monthRange = Range(match.range(at: 1), in: remaining),
           let dayRange = Range(match.range(at: 2), in: remaining),
           let fullRange = Range(match.range, in: remaining),
           let month = Int(remaining[monthRange]),
           let day = Int(remaining[dayRange]) {
            var comps = cal.dateComponents([.year], from: now)
            comps.month = month
            comps.day = day
            if let date = cal.date(from: comps) {
                baseDate = date < today
                    ? cal.date(byAdding: .year, value: 1, to: date)
                    : date
                remaining.removeSubrange(fullRange)
                foundDate = true
            }
        }

        // --- Simple keywords: 글피, 모레, 내일, 오늘 (order: longest match first) ---
        if !foundDate {
            for (kw, offset) in DateParsingCommon.koreanRelativeDays {
                if let range = remaining.range(of: kw) {
                    baseDate = cal.date(byAdding: .day, value: offset, to: today)
                    remaining.removeSubrange(range)
                    foundDate = true
                    break
                }
            }
        }

        // --- Time: "오후 3시 30분" / "오전 10시" / "3시반" / "15시" ---
        if let regex = try? NSRegularExpression(
            pattern: "(오전|오후)?\\s*(\\d{1,2})\\s*시\\s*(?:(\\d{1,2})\\s*분|(반))?\\s*(?:에)?"
        ),
           let match = regex.firstMatch(in: remaining, range: nsRange(remaining)),
           let hourRange = Range(match.range(at: 2), in: remaining),
           let fullRange = Range(match.range, in: remaining) {

            hour = Int(remaining[hourRange])

            if match.range(at: 1).location != NSNotFound,
               let ampmRange = Range(match.range(at: 1), in: remaining) {
                isPM = String(remaining[ampmRange]) == "오후"
            }

            if match.range(at: 3).location != NSNotFound,
               let minRange = Range(match.range(at: 3), in: remaining) {
                minute = Int(remaining[minRange]) ?? 0
            } else if match.range(at: 4).location != NSNotFound {
                minute = 30 // 반 = half past
            }

            remaining.removeSubrange(fullRange)
            foundTime = true
        }

        // Must have found at least one Korean date or time component
        guard foundDate || foundTime else { return nil }

        // Default to today if only time was specified
        if baseDate == nil { baseDate = today }

        // Apply time to base date
        var startDate = baseDate!
        if let h = hour {
            var adjusted = h
            if let pm = isPM {
                if pm && h < 12 { adjusted = h + 12 }
                else if !pm && h == 12 { adjusted = 0 }
            }
            startDate = cal.date(bySettingHour: adjusted, minute: minute, second: 0, of: startDate)
                ?? startDate
        }

        let isAllDay = !foundTime
        let endDate = isAllDay ? nil : cal.date(byAdding: .minute, value: 60, to: startDate)

        let title = cleanTitle(remaining)

        return ParsedEvent(
            title: title.isEmpty ? "New Event" : title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay
        )
    }

    // MARK: - NSDataDetector Parser (English / system locale)

    private static func parseWithDetector(_ input: String) -> ParsedEvent {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.date.rawValue
        ) else {
            return ParsedEvent(title: input, startDate: nil, endDate: nil, isAllDay: false)
        }

        let matches = detector.matches(in: input, options: [], range: nsRange(input))

        guard let match = matches.first, let date = match.date else {
            return ParsedEvent(title: input, startDate: nil, endDate: nil, isAllDay: false)
        }

        let matchRange = Range(match.range, in: input)!
        var title = input
        title.removeSubrange(matchRange)
        title = cleanTitle(title)

        let duration = match.duration
        let endDate: Date?
        if duration > 0 {
            endDate = date.addingTimeInterval(duration)
        } else {
            endDate = Calendar.current.date(byAdding: .minute, value: 60, to: date)
        }

        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let isAllDay = (h == 0 && m == 0 && duration == 0)

        return ParsedEvent(
            title: title.isEmpty ? "New Event" : title,
            startDate: date,
            endDate: endDate,
            isAllDay: isAllDay
        )
    }

    // MARK: - Helpers

    private static func nsRange(_ str: String) -> NSRange {
        NSRange(str.startIndex..., in: str)
    }

    private static func koreanWeekday(_ char: String) -> Int? {
        DateParsingCommon.koreanWeekdayMap[char]
    }

    /// Weekday in current or offset week. weekOffset 0 = this week, 1 = next week.
    private static func targetWeekday(_ weekday: Int, weekOffset: Int, from today: Date) -> Date {
        let cal = Calendar.current
        let todayWd = cal.component(.weekday, from: today)
        let diff = (weekday - todayWd) + (weekOffset * 7)
        guard let date = cal.date(byAdding: .day, value: diff, to: today) else { return today }
        return cal.startOfDay(for: date)
    }

    /// Next occurrence of a weekday starting from tomorrow.
    private static func nextOccurrence(of weekday: Int, after today: Date) -> Date {
        let cal = Calendar.current
        var date = today
        for _ in 1...7 {
            guard let next = cal.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
            if cal.component(.weekday, from: date) == weekday {
                return cal.startOfDay(for: date)
            }
        }
        return cal.startOfDay(for: date)
    }

    /// Cleans title by stripping orphaned Korean particles and English prepositions.
    private static func cleanTitle(_ raw: String) -> String {
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip leading Korean particles (에서, 까지, 부터, 에 — longest first)
        let koreanParticles = ["에서", "까지", "부터", "에"]
        for p in koreanParticles {
            let pattern = "^\(p)\\s*"
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        // Strip trailing Korean particles
        for p in koreanParticles {
            let pattern = "\\s*\(p)$"
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        // Strip English trailing/leading prepositions
        let englishTrailing = ["at", "on", "for", "from", "in", "by", "until", "to", "the"]
        var words = result.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        while let last = words.last?.lowercased(), englishTrailing.contains(last) {
            words.removeLast()
        }
        while let first = words.first?.lowercased(), englishTrailing.contains(first) {
            words.removeFirst()
        }

        return words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

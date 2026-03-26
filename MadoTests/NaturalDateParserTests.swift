import XCTest
@testable import Mado

/// Unit tests for NaturalDateParser.
/// Each test verifies one specific parsing behaviour against a fixed reference date.
///
/// Reference: Wednesday 2026-03-25 (weekday 4 in Calendar, where Sun=1)
final class NaturalDateParserTests: XCTestCase {

    // MARK: - Helpers

    /// Build a fixed "today" of 2026-03-25 00:00:00 local time for deterministic tests.
    private var referenceDate: Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 3
        comps.day = 25
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps)!
    }

    /// Returns the start-of-day for a date offset from referenceDate.
    private func dayOffset(_ days: Int) -> Date {
        Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: days, to: referenceDate)!
        )
    }

    /// Build a Date at referenceDate + dayOffset days, set to h:m.
    private func dateAt(dayOffset days: Int = 0, hour: Int, minute: Int = 0) -> Date {
        let base = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: days, to: referenceDate)!
        )
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    // MARK: - Edge cases

    func testEmptyStringReturnsNilDueDate() {
        let result = NaturalDateParser.parse("")
        XCTAssertNil(result.dueDate)
        XCTAssertEqual(result.title, "")
    }

    func testWhitespaceOnlyStringReturnsNilDueDate() {
        let result = NaturalDateParser.parse("   ")
        XCTAssertNil(result.dueDate)
    }

    func testGarbageInputReturnsNilDueDateAndPreservesTitle() {
        let result = NaturalDateParser.parse("xyzzy!@#$%")
        XCTAssertNil(result.dueDate)
        XCTAssertEqual(result.title, "xyzzy!@#$%")
    }

    // MARK: - Korean relative day keywords

    func testKorean_오늘_parsesToStartOfToday() {
        let result = NaturalDateParser.parse("오늘 미팅")
        XCTAssertNotNil(result.dueDate)
        let expected = Calendar.current.startOfDay(for: Date())
        let resultDay = Calendar.current.startOfDay(for: result.dueDate!)
        XCTAssertEqual(resultDay, expected)
        XCTAssertEqual(result.title, "미팅")
    }

    func testKorean_내일_parsesToTomorrow() {
        let result = NaturalDateParser.parse("내일 팀 스탠드업")
        XCTAssertNotNil(result.dueDate)
        let expectedDay = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        let resultDay = Calendar.current.startOfDay(for: result.dueDate!)
        XCTAssertEqual(resultDay, expectedDay)
        XCTAssertFalse(result.title.contains("내일"))
    }

    func testKorean_모레_parsesToDayAfterTomorrow() {
        let result = NaturalDateParser.parse("모레 보고서 제출")
        XCTAssertNotNil(result.dueDate)
        let expectedDay = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        )
        let resultDay = Calendar.current.startOfDay(for: result.dueDate!)
        XCTAssertEqual(resultDay, expectedDay)
        XCTAssertFalse(result.title.contains("모레"))
    }

    func testKorean_글피_parsesThreeDaysAhead() {
        let result = NaturalDateParser.parse("글피 약속")
        XCTAssertNotNil(result.dueDate)
        let expectedDay = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        )
        let resultDay = Calendar.current.startOfDay(for: result.dueDate!)
        XCTAssertEqual(resultDay, expectedDay)
    }

    // MARK: - Korean weekday

    func testKorean_다음주월요일_parsesToNextMonday() {
        let result = NaturalDateParser.parse("다음주 월요일 회의")
        XCTAssertNotNil(result.dueDate)
        let weekday = Calendar.current.component(.weekday, from: result.dueDate!)
        XCTAssertEqual(weekday, 2, "월요일 should resolve to Calendar weekday 2 (Monday)")
        // Must be strictly in the future (at least 7 days when today is a weekday)
        XCTAssertGreaterThan(result.dueDate!, Date())
    }

    func testKorean_다음주금요일_parsesToNextFriday() {
        let result = NaturalDateParser.parse("다음주 금요일 데모")
        XCTAssertNotNil(result.dueDate)
        let weekday = Calendar.current.component(.weekday, from: result.dueDate!)
        XCTAssertEqual(weekday, 6, "금요일 should resolve to Calendar weekday 6 (Friday)")
    }

    // MARK: - English relative keywords

    func testEnglish_today_parsesToStartOfToday() {
        let result = NaturalDateParser.parse("Team sync today")
        XCTAssertNotNil(result.dueDate)
        let expectedDay = Calendar.current.startOfDay(for: Date())
        let resultDay = Calendar.current.startOfDay(for: result.dueDate!)
        XCTAssertEqual(resultDay, expectedDay)
        XCTAssertFalse(result.title.lowercased().contains("today"))
    }

    func testEnglish_tomorrow_parsesToTomorrow() {
        let result = NaturalDateParser.parse("Deploy tomorrow")
        XCTAssertNotNil(result.dueDate)
        let expectedDay = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        let resultDay = Calendar.current.startOfDay(for: result.dueDate!)
        XCTAssertEqual(resultDay, expectedDay)
    }

    func testEnglish_nextMonday_parsesToNextMonday() {
        let result = NaturalDateParser.parse("Review PR next monday")
        XCTAssertNotNil(result.dueDate)
        let weekday = Calendar.current.component(.weekday, from: result.dueDate!)
        XCTAssertEqual(weekday, 2)
        XCTAssertGreaterThan(result.dueDate!, Date())
    }

    func testEnglish_nextFriday_parsesToNextFriday() {
        let result = NaturalDateParser.parse("Ship release next friday")
        XCTAssertNotNil(result.dueDate)
        let weekday = Calendar.current.component(.weekday, from: result.dueDate!)
        XCTAssertEqual(weekday, 6)
    }

    func testEnglish_bareDayName_parsesToNextOccurrence() {
        let result = NaturalDateParser.parse("Submit report Wednesday")
        XCTAssertNotNil(result.dueDate)
        let weekday = Calendar.current.component(.weekday, from: result.dueDate!)
        XCTAssertEqual(weekday, 4, "Wednesday should be weekday 4")
    }

    // MARK: - Korean time parsing

    func testKorean_오후3시_parsesTo15h() {
        let result = NaturalDateParser.parse("오후 3시 미팅")
        XCTAssertNotNil(result.dueDate)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        XCTAssertEqual(hour, 15)
    }

    func testKorean_오전10시_parsesTo10h() {
        let result = NaturalDateParser.parse("오전 10시 회의")
        XCTAssertNotNil(result.dueDate)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        XCTAssertEqual(hour, 10)
    }

    func testKorean_오후12시_parsesTo12h_noon() {
        let result = NaturalDateParser.parse("오후 12시 점심")
        XCTAssertNotNil(result.dueDate)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        XCTAssertEqual(hour, 12)
    }

    func testKorean_오전12시_parsesTo0h_midnight() {
        let result = NaturalDateParser.parse("오전 12시 취침")
        XCTAssertNotNil(result.dueDate)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        XCTAssertEqual(hour, 0)
    }

    func testKorean_시반_parsesTo30minutes() {
        let result = NaturalDateParser.parse("오후 3시 반 산책")
        XCTAssertNotNil(result.dueDate)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        let minute = Calendar.current.component(.minute, from: result.dueDate!)
        XCTAssertEqual(hour, 15)
        XCTAssertEqual(minute, 30)
    }

    func testKorean_시분_parsesMinutes() {
        let result = NaturalDateParser.parse("오전 9시 30분 스탠드업")
        XCTAssertNotNil(result.dueDate)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        let minute = Calendar.current.component(.minute, from: result.dueDate!)
        XCTAssertEqual(hour, 9)
        XCTAssertEqual(minute, 30)
    }

    // MARK: - English time parsing

    func testEnglish_3pm_parsesTo15h() {
        let result = NaturalDateParser.parse("Call 3pm")
        XCTAssertNotNil(result.dueDate)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        XCTAssertEqual(hour, 15)
    }

    func testEnglish_9am_parsesTo9h() {
        let result = NaturalDateParser.parse("Standup 9am")
        XCTAssertNotNil(result.dueDate)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        XCTAssertEqual(hour, 9)
    }

    func testEnglish_colonTime_3_30pm_parsesCorrectly() {
        let result = NaturalDateParser.parse("Review 3:30pm")
        XCTAssertNotNil(result.dueDate)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        let minute = Calendar.current.component(.minute, from: result.dueDate!)
        XCTAssertEqual(hour, 15)
        XCTAssertEqual(minute, 30)
    }

    func testEnglish_15_00_parsesAs24hHour() {
        // "15시" — bare 24h hour without am/pm
        let result = NaturalDateParser.parse("15시 회의")
        XCTAssertNotNil(result.dueDate)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        XCTAssertEqual(hour, 15)
    }

    // MARK: - Date + time combination

    func testKorean_내일오후3시_combinesDateAndTime() {
        let result = NaturalDateParser.parse("내일 오후 3시 미팅")
        XCTAssertNotNil(result.dueDate)
        let expectedDay = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        let resultDay = Calendar.current.startOfDay(for: result.dueDate!)
        XCTAssertEqual(resultDay, expectedDay)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        XCTAssertEqual(hour, 15)
    }

    func testEnglish_tomorrowAt9am_combinesDateAndTime() {
        let result = NaturalDateParser.parse("Team sync tomorrow 9am")
        XCTAssertNotNil(result.dueDate)
        let expectedDay = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        let resultDay = Calendar.current.startOfDay(for: result.dueDate!)
        XCTAssertEqual(resultDay, expectedDay)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        XCTAssertEqual(hour, 9)
    }

    // MARK: - Title extraction

    func testTitleIsPreservedAfterDateRemoval_korean() {
        let result = NaturalDateParser.parse("내일 오후 3시 팀 미팅")
        XCTAssertEqual(result.title, "팀 미팅")
    }

    func testTitleIsPreservedAfterDateRemoval_english() {
        let result = NaturalDateParser.parse("Deploy to production tomorrow 9am")
        XCTAssertEqual(result.title, "Deploy to production")
    }

    func testPureDateInputDefaultsToNineAM() {
        let result = NaturalDateParser.parse("내일 보고서")
        XCTAssertNotNil(result.dueDate)
        let hour = Calendar.current.component(.hour, from: result.dueDate!)
        XCTAssertEqual(hour, 9, "Date-only input should default to 9:00 AM")
    }

    // MARK: - Highlight ranges

    func testHighlightRangesEmptyStringReturnsEmptyArray() {
        let ranges = NaturalDateParser.highlightRanges("")
        XCTAssertTrue(ranges.isEmpty)
    }

    func testHighlightRangesReturnsRangeForDateToken() {
        let input = "내일 미팅"
        let ranges = NaturalDateParser.highlightRanges(input)
        XCTAssertFalse(ranges.isEmpty)
        // The highlighted substring should contain the date token
        let highlighted = String(input[ranges[0]])
        XCTAssertTrue(highlighted.contains("내일"))
    }

    func testHighlightRangesReturnsRangeForTimeToken() {
        let input = "오후 3시 회의"
        let ranges = NaturalDateParser.highlightRanges(input)
        XCTAssertFalse(ranges.isEmpty)
    }
}

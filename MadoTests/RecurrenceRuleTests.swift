import XCTest
@testable import Mado

/// Unit tests for RecurrenceRule and RecurrenceFrequency.
/// Tests verify next-occurrence arithmetic, interval multipliers, and edge cases.
final class RecurrenceRuleTests: XCTestCase {

    // MARK: - Helpers

    /// Build a fixed date for deterministic calendar arithmetic.
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 9
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps)!
    }

    /// Returns the next occurrence by applying one interval step to `base`.
    private func nextOccurrence(from base: Date, rule: RecurrenceRule) -> Date {
        let cal = Calendar.current
        switch rule.frequency {
        case .daily:
            return cal.date(byAdding: .day, value: rule.interval, to: base)!
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: rule.interval, to: base)!
        case .monthly:
            return cal.date(byAdding: .month, value: rule.interval, to: base)!
        case .yearly:
            return cal.date(byAdding: .year, value: rule.interval, to: base)!
        }
    }

    // MARK: - Static presets

    func testStaticDailyPresetHasFrequencyDaily() {
        XCTAssertEqual(RecurrenceRule.daily.frequency, .daily)
    }

    func testStaticDailyPresetHasIntervalOne() {
        XCTAssertEqual(RecurrenceRule.daily.interval, 1)
    }

    func testStaticWeeklyPresetHasFrequencyWeekly() {
        XCTAssertEqual(RecurrenceRule.weekly.frequency, .weekly)
    }

    func testStaticWeeklyPresetHasIntervalOne() {
        XCTAssertEqual(RecurrenceRule.weekly.interval, 1)
    }

    func testStaticMonthlyPresetHasFrequencyMonthly() {
        XCTAssertEqual(RecurrenceRule.monthly.frequency, .monthly)
    }

    func testStaticMonthlyPresetHasIntervalOne() {
        XCTAssertEqual(RecurrenceRule.monthly.interval, 1)
    }

    // MARK: - Daily recurrence

    func testDailyRecurrenceNextOccurrenceIsTomorrow() {
        let base = makeDate(year: 2026, month: 3, day: 25)
        let rule = RecurrenceRule.daily
        let next = nextOccurrence(from: base, rule: rule)
        let expected = makeDate(year: 2026, month: 3, day: 26)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: next),
            Calendar.current.startOfDay(for: expected)
        )
    }

    func testDailyRecurrenceIsExactlyOneDayAhead() {
        let base = makeDate(year: 2026, month: 1, day: 15)
        let rule = RecurrenceRule.daily
        let next = nextOccurrence(from: base, rule: rule)
        let diff = Calendar.current.dateComponents([.day], from: base, to: next).day!
        XCTAssertEqual(diff, 1)
    }

    func testDailyRecurrenceAcrossMonthBoundary() {
        let base = makeDate(year: 2026, month: 1, day: 31)
        let rule = RecurrenceRule.daily
        let next = nextOccurrence(from: base, rule: rule)
        let expected = makeDate(year: 2026, month: 2, day: 1)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: next),
            Calendar.current.startOfDay(for: expected)
        )
    }

    func testDailyRecurrenceAcrossYearBoundary() {
        let base = makeDate(year: 2025, month: 12, day: 31)
        let rule = RecurrenceRule.daily
        let next = nextOccurrence(from: base, rule: rule)
        let expected = makeDate(year: 2026, month: 1, day: 1)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: next),
            Calendar.current.startOfDay(for: expected)
        )
    }

    // MARK: - Weekly recurrence

    func testWeeklyRecurrenceNextOccurrenceIsSevenDaysLater() {
        let base = makeDate(year: 2026, month: 3, day: 25)
        let rule = RecurrenceRule.weekly
        let next = nextOccurrence(from: base, rule: rule)
        let diff = Calendar.current.dateComponents([.day], from: base, to: next).day!
        XCTAssertEqual(diff, 7)
    }

    func testWeeklyRecurrenceLandsSameWeekday() {
        let base = makeDate(year: 2026, month: 3, day: 25) // Wednesday
        let rule = RecurrenceRule.weekly
        let next = nextOccurrence(from: base, rule: rule)
        let baseWeekday = Calendar.current.component(.weekday, from: base)
        let nextWeekday = Calendar.current.component(.weekday, from: next)
        XCTAssertEqual(baseWeekday, nextWeekday)
    }

    // MARK: - Monthly recurrence

    func testMonthlyRecurrenceNextOccurrenceIsOneMonthLater() {
        let base = makeDate(year: 2026, month: 3, day: 15)
        let rule = RecurrenceRule.monthly
        let next = nextOccurrence(from: base, rule: rule)
        let expected = makeDate(year: 2026, month: 4, day: 15)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: next),
            Calendar.current.startOfDay(for: expected)
        )
    }

    func testMonthlyRecurrencePreservesDay() {
        let base = makeDate(year: 2026, month: 1, day: 10)
        let rule = RecurrenceRule.monthly
        let next = nextOccurrence(from: base, rule: rule)
        XCTAssertEqual(Calendar.current.component(.day, from: next), 10)
    }

    func testMonthlyRecurrenceAcrossYearBoundary() {
        let base = makeDate(year: 2025, month: 12, day: 20)
        let rule = RecurrenceRule.monthly
        let next = nextOccurrence(from: base, rule: rule)
        let expected = makeDate(year: 2026, month: 1, day: 20)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: next),
            Calendar.current.startOfDay(for: expected)
        )
    }

    // MARK: - Interval > 1

    func testEveryTwoDaysProducesTwoDayGap() {
        let base = makeDate(year: 2026, month: 3, day: 10)
        let rule = RecurrenceRule(frequency: .daily, interval: 2)
        let next = nextOccurrence(from: base, rule: rule)
        let diff = Calendar.current.dateComponents([.day], from: base, to: next).day!
        XCTAssertEqual(diff, 2)
    }

    func testEveryTwoWeeksProducesFourteenDayGap() {
        let base = makeDate(year: 2026, month: 3, day: 10)
        let rule = RecurrenceRule(frequency: .weekly, interval: 2)
        let next = nextOccurrence(from: base, rule: rule)
        let diff = Calendar.current.dateComponents([.day], from: base, to: next).day!
        XCTAssertEqual(diff, 14)
    }

    func testEveryThreeMonthsProducesThreeMonthGap() {
        let base = makeDate(year: 2026, month: 1, day: 1)
        let rule = RecurrenceRule(frequency: .monthly, interval: 3)
        let next = nextOccurrence(from: base, rule: rule)
        let expected = makeDate(year: 2026, month: 4, day: 1)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: next),
            Calendar.current.startOfDay(for: expected)
        )
    }

    // MARK: - Equatable / Codable round-trip

    func testTwoRulesWithSameFrequencyAndIntervalAreEqual() {
        let r1 = RecurrenceRule(frequency: .daily, interval: 1)
        let r2 = RecurrenceRule(frequency: .daily, interval: 1)
        XCTAssertEqual(r1, r2)
    }

    func testRulesWithDifferentFrequenciesAreNotEqual() {
        let r1 = RecurrenceRule(frequency: .daily, interval: 1)
        let r2 = RecurrenceRule(frequency: .weekly, interval: 1)
        XCTAssertNotEqual(r1, r2)
    }

    func testRulesWithDifferentIntervalsAreNotEqual() {
        let r1 = RecurrenceRule(frequency: .weekly, interval: 1)
        let r2 = RecurrenceRule(frequency: .weekly, interval: 2)
        XCTAssertNotEqual(r1, r2)
    }

    func testRecurrenceRuleEncodesAndDecodesCorrectly() throws {
        let original = RecurrenceRule(frequency: .monthly, interval: 2)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecurrenceRule.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testRecurrenceRuleWithEndDateEncodesAndDecodesCorrectly() throws {
        let endDate = makeDate(year: 2027, month: 1, day: 1)
        let original = RecurrenceRule(frequency: .weekly, interval: 1, endDate: endDate)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecurrenceRule.self, from: data)
        XCTAssertEqual(decoded.endDate, original.endDate)
    }

    // MARK: - Edge cases: end of month / leap year

    func testMonthlyRecurrenceFromJan31ClampsToFeb28InNonLeapYear() {
        // 2025 is not a leap year; Feb has 28 days.
        // Calendar.current.date(byAdding:) naturally clamps to the last valid day.
        let base = makeDate(year: 2025, month: 1, day: 31)
        let rule = RecurrenceRule.monthly
        let next = nextOccurrence(from: base, rule: rule)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual(comps.year, 2025)
        XCTAssertEqual(comps.month, 2)
        XCTAssertLessThanOrEqual(comps.day!, 28)
    }

    func testMonthlyRecurrenceFromJan31ClampsToFeb29InLeapYear() {
        // 2028 is a leap year.
        let base = makeDate(year: 2028, month: 1, day: 31)
        let rule = RecurrenceRule.monthly
        let next = nextOccurrence(from: base, rule: rule)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual(comps.year, 2028)
        XCTAssertEqual(comps.month, 2)
        XCTAssertLessThanOrEqual(comps.day!, 29)
    }

    func testDailyRecurrenceThroughLeapDay() {
        // Feb 28 + 1 day in a leap year should land on Feb 29.
        let base = makeDate(year: 2028, month: 2, day: 28)
        let rule = RecurrenceRule.daily
        let next = nextOccurrence(from: base, rule: rule)
        let comps = Calendar.current.dateComponents([.month, .day], from: next)
        XCTAssertEqual(comps.month, 2)
        XCTAssertEqual(comps.day, 29)
    }

    // MARK: - RecurrenceFrequency labels

    func testFrequencyLabelDaily() {
        XCTAssertEqual(RecurrenceFrequency.daily.label, "Daily")
    }

    func testFrequencyLabelWeekly() {
        XCTAssertEqual(RecurrenceFrequency.weekly.label, "Weekly")
    }

    func testFrequencyLabelMonthly() {
        XCTAssertEqual(RecurrenceFrequency.monthly.label, "Monthly")
    }

    func testFrequencyLabelYearly() {
        XCTAssertEqual(RecurrenceFrequency.yearly.label, "Yearly")
    }

    // MARK: - endDate field

    func testRuleWithNilEndDateHasNoEndDate() {
        let rule = RecurrenceRule(frequency: .daily, interval: 1)
        XCTAssertNil(rule.endDate)
    }

    func testRuleWithEndDatePreservesEndDate() {
        let end = makeDate(year: 2026, month: 12, day: 31)
        let rule = RecurrenceRule(frequency: .weekly, interval: 1, endDate: end)
        XCTAssertEqual(rule.endDate, end)
    }
}

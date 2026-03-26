import XCTest
import SwiftData
@testable import Mado

/// Unit tests for the MadoTask SwiftData model.
/// Each test uses an in-memory ModelContainer so no disk state is shared between runs.
final class MadoTaskTests: XCTestCase {

    // MARK: - Test infrastructure

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([MadoTask.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - Creation & default values

    func testTaskCreationWithTitleSetsTitle() throws {
        let task = MadoTask(title: "Write unit tests")
        XCTAssertEqual(task.title, "Write unit tests")
    }

    func testTaskCreationDefaultsIsCompletedToFalse() throws {
        let task = MadoTask(title: "Some task")
        XCTAssertFalse(task.isCompleted)
    }

    func testTaskCreationDefaultsIsDeletedToFalse() throws {
        let task = MadoTask(title: "Some task")
        XCTAssertFalse(task.isDeleted)
    }

    func testTaskCreationDefaultsNeedsSyncToTrue() throws {
        let task = MadoTask(title: "Some task")
        XCTAssertTrue(task.needsSync)
    }

    func testTaskCreationDefaultsPriorityToNone() throws {
        let task = MadoTask(title: "Some task")
        XCTAssertEqual(task.priority, .none)
    }

    func testTaskCreationDefaultsPositionToZero() throws {
        let task = MadoTask(title: "Some task")
        XCTAssertEqual(task.position, 0)
    }

    func testTaskCreationDefaultsLabelIdsToEmptyArray() throws {
        let task = MadoTask(title: "Some task")
        XCTAssertTrue(task.labelIds.isEmpty)
    }

    func testTaskCreationWithNotesSetsNotes() throws {
        let task = MadoTask(title: "Task", notes: "Important details here")
        XCTAssertEqual(task.notes, "Important details here")
    }

    func testTaskCreationWithNilNotesLeavesNotesNil() throws {
        let task = MadoTask(title: "Task")
        XCTAssertNil(task.notes)
    }

    func testTaskCreationGeneratesNonEmptyId() throws {
        let task = MadoTask(title: "Task")
        XCTAssertFalse(task.id.isEmpty)
    }

    func testTwoTasksCreatedWithoutExplicitIdHaveDistinctIds() throws {
        let t1 = MadoTask(title: "First")
        let t2 = MadoTask(title: "Second")
        XCTAssertNotEqual(t1.id, t2.id)
    }

    // MARK: - Completion

    func testMarkCompletedSetsIsCompletedTrue() throws {
        let task = MadoTask(title: "Finish report")
        task.markCompleted()
        XCTAssertTrue(task.isCompleted)
    }

    func testMarkCompletedSetsCompletedAtToNonNil() throws {
        let task = MadoTask(title: "Finish report")
        let before = Date()
        task.markCompleted()
        XCTAssertNotNil(task.completedAt)
        XCTAssertGreaterThanOrEqual(task.completedAt!, before)
    }

    func testMarkCompletedSetsNeedsSyncTrue() throws {
        let task = MadoTask(title: "Task")
        task.needsSync = false
        task.markCompleted()
        XCTAssertTrue(task.needsSync)
    }

    func testMarkIncompleteSetsIsCompletedFalse() throws {
        let task = MadoTask(title: "Task")
        task.markCompleted()
        task.markIncomplete()
        XCTAssertFalse(task.isCompleted)
    }

    func testMarkIncompleteClearsCompletedAt() throws {
        let task = MadoTask(title: "Task")
        task.markCompleted()
        task.markIncomplete()
        XCTAssertNil(task.completedAt)
    }

    func testMarkIncompleteSetsNeedsSyncTrue() throws {
        let task = MadoTask(title: "Task")
        task.markCompleted()
        task.needsSync = false
        task.markIncomplete()
        XCTAssertTrue(task.needsSync)
    }

    // MARK: - Soft deletion

    func testIsDeletedDefaultsFalseOnNewTask() throws {
        let task = MadoTask(title: "Task")
        XCTAssertFalse(task.isDeleted)
    }

    func testSettingIsDeletedTrueMarksTaskDeleted() throws {
        let task = MadoTask(title: "Task")
        task.isDeleted = true
        XCTAssertTrue(task.isDeleted)
    }

    func testSoftDeletedTaskStillExistsInContext() throws {
        let task = MadoTask(title: "Deleted task")
        context.insert(task)
        task.isDeleted = true
        try context.save()

        let descriptor = FetchDescriptor<MadoTask>()
        let all = try context.fetch(descriptor)
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(all[0].isDeleted)
    }

    // MARK: - Priority

    func testSettingPriorityToHighIsReflected() throws {
        let task = MadoTask(title: "Urgent task")
        task.priority = .high
        XCTAssertEqual(task.priority, .high)
    }

    func testTaskPriorityInitialisedFromInit() throws {
        let task = MadoTask(title: "Medium priority task", priority: .medium)
        XCTAssertEqual(task.priority, .medium)
    }

    func testPrioritySortOrderMatchesRawValue() {
        XCTAssertEqual(TaskPriority.none.sortOrder, 0)
        XCTAssertEqual(TaskPriority.low.sortOrder, 1)
        XCTAssertEqual(TaskPriority.medium.sortOrder, 2)
        XCTAssertEqual(TaskPriority.high.sortOrder, 3)
    }

    func testPriorityHighSortOrderExceedsLow() {
        XCTAssertGreaterThan(TaskPriority.high.sortOrder, TaskPriority.low.sortOrder)
    }

    func testPriorityLabelReturnsCorrectString() {
        XCTAssertEqual(TaskPriority.none.label, "None")
        XCTAssertEqual(TaskPriority.low.label, "Low")
        XCTAssertEqual(TaskPriority.medium.label, "Medium")
        XCTAssertEqual(TaskPriority.high.label, "High")
    }

    // MARK: - Position / ordering

    func testPositionDefaultsToZero() throws {
        let task = MadoTask(title: "Task")
        XCTAssertEqual(task.position, 0)
    }

    func testPositionCanBeUpdated() throws {
        let task = MadoTask(title: "Task", position: 5)
        XCTAssertEqual(task.position, 5)
        task.position = 10
        XCTAssertEqual(task.position, 10)
    }

    func testMultipleTasksCanHaveDistinctPositions() throws {
        let t1 = MadoTask(title: "First", position: 0)
        let t2 = MadoTask(title: "Second", position: 1)
        let t3 = MadoTask(title: "Third", position: 2)
        context.insert(t1)
        context.insert(t2)
        context.insert(t3)
        try context.save()

        var descriptor = FetchDescriptor<MadoTask>(
            sortBy: [SortDescriptor(\.position)]
        )
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.map(\.position), [0, 1, 2])
    }

    // MARK: - needsSync flag

    func testNeedsSyncDefaultsTrueOnCreation() {
        let task = MadoTask(title: "Task")
        XCTAssertTrue(task.needsSync)
    }

    func testMarkUpdatedSetsNeedsSyncTrue() {
        let task = MadoTask(title: "Task")
        task.needsSync = false
        task.markUpdated()
        XCTAssertTrue(task.needsSync)
    }

    func testMarkUpdatedUpdatesLocalUpdatedAt() {
        let task = MadoTask(title: "Task")
        let before = Date()
        task.markUpdated()
        XCTAssertGreaterThanOrEqual(task.localUpdatedAt, before)
    }

    func testNeedsSyncCanBeManuallyCleared() {
        let task = MadoTask(title: "Task")
        task.needsSync = false
        XCTAssertFalse(task.needsSync)
    }

    // MARK: - Recurrence

    func testNewTaskIsNotRecurring() {
        let task = MadoTask(title: "Task")
        XCTAssertFalse(task.isRecurring)
        XCTAssertNil(task.recurrenceRule)
    }

    func testSettingRecurrenceRuleMarksTaskAsRecurring() {
        let task = MadoTask(title: "Weekly review")
        task.recurrenceRule = .weekly
        XCTAssertTrue(task.isRecurring)
    }

    func testRecurrenceRuleRoundTrips() {
        let task = MadoTask(title: "Daily standup")
        let rule = RecurrenceRule(frequency: .daily, interval: 1)
        task.recurrenceRule = rule
        XCTAssertEqual(task.recurrenceRule, rule)
    }

    func testClearingRecurrenceRuleMarksTaskAsNotRecurring() {
        let task = MadoTask(title: "Task")
        task.recurrenceRule = .weekly
        task.recurrenceRule = nil
        XCTAssertFalse(task.isRecurring)
    }

    // MARK: - SwiftData persistence round-trip

    func testTaskPersistsAndFetchesFromInMemoryContainer() throws {
        let task = MadoTask(title: "Persisted task", priority: .high)
        context.insert(task)
        try context.save()

        let descriptor = FetchDescriptor<MadoTask>(
            predicate: #Predicate { $0.title == "Persisted task" }
        )
        let results = try context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].priority, .high)
    }

    func testDueDateIsPersistedCorrectly() throws {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 1; comps.hour = 9
        let due = Calendar.current.date(from: comps)!

        let task = MadoTask(title: "April Fools task", dueDate: due)
        context.insert(task)
        try context.save()

        let descriptor = FetchDescriptor<MadoTask>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched[0].dueDate, due)
    }
}

import XCTest
@testable import Mado

/// Unit tests for SyncErrorKind and SyncStatus.
/// Verifies Korean display messages, enum state predicates, and associated-value extraction.
final class SyncErrorKindTests: XCTestCase {

    // MARK: - SyncErrorKind.displayMessage

    func testNetworkUnavailableDisplayMessageIsKorean() {
        let kind = SyncErrorKind.networkUnavailable
        XCTAssertEqual(kind.displayMessage, "인터넷 연결 없음")
    }

    func testAuthExpiredDisplayMessageIsKorean() {
        let kind = SyncErrorKind.authExpired
        XCTAssertEqual(kind.displayMessage, "세션 만료 — 다시 로그인하세요")
    }

    func testApiErrorDisplayMessageContainsServiceName() {
        let kind = SyncErrorKind.apiError(service: "Calendar", message: "rate limited")
        XCTAssertTrue(kind.displayMessage.contains("Calendar"))
    }

    func testApiErrorDisplayMessageContainsErrorMessage() {
        let kind = SyncErrorKind.apiError(service: "Tasks", message: "quota exceeded")
        XCTAssertTrue(kind.displayMessage.contains("quota exceeded"))
    }

    func testApiErrorDisplayMessageFormatsAsServiceColonMessage() {
        let kind = SyncErrorKind.apiError(service: "Gmail", message: "forbidden")
        XCTAssertEqual(kind.displayMessage, "Gmail: forbidden")
    }

    func testStoreErrorDisplayMessageContainsPayload() {
        let kind = SyncErrorKind.storeError("migration failed")
        XCTAssertTrue(kind.displayMessage.contains("migration failed"))
    }

    func testStoreErrorDisplayMessageHasKoreanPrefix() {
        let kind = SyncErrorKind.storeError("disk full")
        XCTAssertTrue(kind.displayMessage.hasPrefix("저장소 오류:"))
    }

    // MARK: - SyncErrorKind Equatable

    func testNetworkUnavailableEqualsItself() {
        XCTAssertEqual(SyncErrorKind.networkUnavailable, SyncErrorKind.networkUnavailable)
    }

    func testAuthExpiredEqualsItself() {
        XCTAssertEqual(SyncErrorKind.authExpired, SyncErrorKind.authExpired)
    }

    func testApiErrorWithSameValuesAreEqual() {
        let a = SyncErrorKind.apiError(service: "X", message: "Y")
        let b = SyncErrorKind.apiError(service: "X", message: "Y")
        XCTAssertEqual(a, b)
    }

    func testApiErrorWithDifferentServicesAreNotEqual() {
        let a = SyncErrorKind.apiError(service: "Calendar", message: "err")
        let b = SyncErrorKind.apiError(service: "Tasks", message: "err")
        XCTAssertNotEqual(a, b)
    }

    func testStoreErrorWithSameMessageIsEqual() {
        let a = SyncErrorKind.storeError("boom")
        let b = SyncErrorKind.storeError("boom")
        XCTAssertEqual(a, b)
    }

    func testNetworkUnavailableAndAuthExpiredAreNotEqual() {
        XCTAssertNotEqual(SyncErrorKind.networkUnavailable, SyncErrorKind.authExpired)
    }

    // MARK: - SyncStatus.isSyncing

    func testSyncStatusIdleIsNotSyncing() {
        XCTAssertFalse(SyncStatus.idle.isSyncing)
    }

    func testSyncStatusSyncingIsSyncing() {
        XCTAssertTrue(SyncStatus.syncing.isSyncing)
    }

    func testSyncStatusSuccessIsNotSyncing() {
        XCTAssertFalse(SyncStatus.success(Date()).isSyncing)
    }

    func testSyncStatusErrorIsNotSyncing() {
        XCTAssertFalse(SyncStatus.error(.networkUnavailable).isSyncing)
    }

    // MARK: - SyncStatus.lastSyncDate

    func testSuccessStatusReturnsLastSyncDate() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let status = SyncStatus.success(date)
        XCTAssertEqual(status.lastSyncDate, date)
    }

    func testIdleStatusReturnsNilLastSyncDate() {
        XCTAssertNil(SyncStatus.idle.lastSyncDate)
    }

    func testSyncingStatusReturnsNilLastSyncDate() {
        XCTAssertNil(SyncStatus.syncing.lastSyncDate)
    }

    func testErrorStatusReturnsNilLastSyncDate() {
        XCTAssertNil(SyncStatus.error(.authExpired).lastSyncDate)
    }

    // MARK: - SyncStatus.displayText

    func testIdleDisplayTextIsKorean() {
        XCTAssertEqual(SyncStatus.idle.displayText, "동기화 안 됨")
    }

    func testSyncingDisplayTextIsKorean() {
        XCTAssertEqual(SyncStatus.syncing.displayText, "동기화 중...")
    }

    func testSuccessDisplayTextContainsSyncWord() {
        let status = SyncStatus.success(Date())
        XCTAssertTrue(status.displayText.contains("동기화됨"))
    }

    func testErrorDisplayTextContainsErrorKindMessage() {
        let status = SyncStatus.error(.networkUnavailable)
        XCTAssertTrue(status.displayText.contains("인터넷 연결 없음"))
    }

    func testErrorDisplayTextWithApiErrorContainsServiceName() {
        let status = SyncStatus.error(.apiError(service: "Calendar", message: "timeout"))
        XCTAssertTrue(status.displayText.contains("Calendar"))
    }

    // MARK: - SyncStatus Equatable

    func testIdleEqualsIdle() {
        XCTAssertEqual(SyncStatus.idle, SyncStatus.idle)
    }

    func testSyncingEqualsSyncing() {
        XCTAssertEqual(SyncStatus.syncing, SyncStatus.syncing)
    }

    func testSuccessWithSameDatesAreEqual() {
        let date = Date(timeIntervalSinceReferenceDate: 1000)
        XCTAssertEqual(SyncStatus.success(date), SyncStatus.success(date))
    }

    func testSuccessWithDifferentDatesAreNotEqual() {
        let d1 = Date(timeIntervalSinceReferenceDate: 1000)
        let d2 = Date(timeIntervalSinceReferenceDate: 2000)
        XCTAssertNotEqual(SyncStatus.success(d1), SyncStatus.success(d2))
    }

    func testErrorWithSameKindAreEqual() {
        XCTAssertEqual(
            SyncStatus.error(.authExpired),
            SyncStatus.error(.authExpired)
        )
    }

    func testErrorWithDifferentKindAreNotEqual() {
        XCTAssertNotEqual(
            SyncStatus.error(.authExpired),
            SyncStatus.error(.networkUnavailable)
        )
    }

    func testIdleAndSyncingAreNotEqual() {
        XCTAssertNotEqual(SyncStatus.idle, SyncStatus.syncing)
    }
}

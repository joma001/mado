import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Timer State

enum FocusTimerState: Equatable {
    case idle
    case running
    case paused
    case breakTime
}

// MARK: - FocusTimerViewModel

@MainActor
@Observable
final class FocusTimerViewModel {
    static let shared = FocusTimerViewModel()

    // MARK: - Published State

    private(set) var timerState: FocusTimerState = .idle
    private(set) var remainingSeconds: Int = 0
    private(set) var totalSeconds: Int = 0
    private(set) var sessionCount: Int = 0
    private(set) var currentSessionNumber: Int = 1
    private(set) var linkedTask: MadoTask?
    private(set) var currentSession: FocusSession?
    private(set) var suggestsLongBreak: Bool = false
    private(set) var isBreakLong: Bool = false
    var showSessionNote: Bool = false
    var completedSessionForNote: FocusSession?

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var linkedTaskTitle: String? {
        linkedTask?.title
    }

    // MARK: - Private

    private var timerCancellable: AnyCancellable?
    private var sessionStartTime: Date?
    private var pauseStartTime: Date?
    private var accumulatedPauseSeconds: TimeInterval = 0
    private let settings = AppSettings.shared
    private let dataController = DataController.shared
    private let minimumSessionSeconds = 60
    private let notificationManager = NotificationManager.shared
    private let noteFileManager = NoteFileManager.shared

    private init() {
        recoverActiveSession()
        pruneOldSessions()
    }

    // MARK: - Public API

    func start(task: MadoTask? = nil) {
        // Stop existing session if running
        if timerState == .running || timerState == .paused {
            stopWithoutSaving()
        }

        let workDuration = settings.pomodoroWorkDuration
        totalSeconds = workDuration * 60
        remainingSeconds = totalSeconds
        linkedTask = task
        timerState = .running
        sessionStartTime = Date()
        accumulatedPauseSeconds = 0
        suggestsLongBreak = false

        // Create SwiftData session
        let session = FocusSession(
            taskId: task?.id,
            startTime: Date(),
            durationSeconds: 0,
            sessionNumber: currentSessionNumber
        )
        dataController.createFocusSession(session)
        currentSession = session

        notificationManager.scheduleFocusSessionEnd(afterSeconds: totalSeconds)
        checkMeetingConflicts()
        startTimer()
    }

    func pause() {
        guard timerState == .running else { return }
        timerState = .paused
        pauseStartTime = Date()
        stopTimer()
        notificationManager.cancelFocusNotifications()
    }

    func resume() {
        guard timerState == .paused else { return }
        if let pauseStart = pauseStartTime {
            accumulatedPauseSeconds += Date().timeIntervalSince(pauseStart)
        }
        timerState = .running
        pauseStartTime = nil
        notificationManager.scheduleFocusSessionEnd(afterSeconds: remainingSeconds)
        startTimer()
    }

    func stop() {
        guard timerState != .idle else { return }
        notificationManager.cancelFocusNotifications()

        let elapsed = elapsedActiveSeconds()

        if elapsed >= minimumSessionSeconds, let session = currentSession {
            session.markCompleted()
            updateLinkedTaskStats(durationSeconds: session.durationSeconds)
            sessionCount += 1
            dataController.save()
        } else if let session = currentSession {
            // Too short — remove the session
            dataController.mainContext.delete(session)
            dataController.save()
        }

        resetState()
    }

    func switchTask(to task: MadoTask?) {
        linkedTask = task
        currentSession?.taskId = task?.id
        dataController.save()
    }

    func startBreak() {
        let interval = settings.pomodoroLongBreakInterval
        isBreakLong = (sessionCount % interval == 0) && sessionCount > 0
        let breakDuration = isBreakLong
            ? settings.pomodoroLongBreakDuration
            : settings.pomodoroShortBreakDuration

        totalSeconds = breakDuration * 60
        remainingSeconds = totalSeconds
        timerState = .breakTime
        sessionStartTime = Date()
        accumulatedPauseSeconds = 0
        suggestsLongBreak = false

        notificationManager.scheduleFocusBreakEnd(afterSeconds: totalSeconds)
        startTimer()
    }

    func skipBreak() {
        stopTimer()
        timerState = .idle
        remainingSeconds = 0
        suggestsLongBreak = false
    }

    // MARK: - Timer Engine

    private func startTimer() {
        stopTimer()
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func tick() {
        guard let start = sessionStartTime else { return }

        let elapsed: TimeInterval
        if timerState == .paused {
            return
        }

        elapsed = Date().timeIntervalSince(start) - accumulatedPauseSeconds
        let remaining = max(0, totalSeconds - Int(elapsed))
        remainingSeconds = remaining

        if remaining <= 0 {
            timerCompleted()
        }
    }

    private func timerCompleted() {
        stopTimer()

        if timerState == .breakTime {
            timerState = .idle
            remainingSeconds = 0
            return
        }

        // Work session completed
        if let session = currentSession {
            session.markCompleted()
            updateLinkedTaskStats(durationSeconds: session.durationSeconds)
            appendSessionNote(session: session)
            sessionCount += 1
            currentSessionNumber += 1
            dataController.save()

            // Show session note prompt
            completedSessionForNote = session
            showSessionNote = true
        }

        // Check if long break is suggested
        let interval = settings.pomodoroLongBreakInterval
        if sessionCount % interval == 0 {
            suggestsLongBreak = true
        }

        timerState = .idle
        currentSession = nil
    }

    // MARK: - Task Stats

    private func updateLinkedTaskStats(durationSeconds: Int) {
        guard let task = linkedTask else { return }
        task.focusMinutes += max(1, durationSeconds / 60)
        task.pomodoroCount += 1
        task.markUpdated()
    }

    // MARK: - Session Notes

    private func appendSessionNote(session: FocusSession) {
        guard settings.pomodoroAutoAppendNotes else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let startStr = formatter.string(from: session.startTime)
        let endStr = formatter.string(from: session.endTime ?? Date())
        let taskName = linkedTask?.title ?? "Quick Focus"
        let minutes = max(1, session.durationSeconds / 60)

        var entry = "\n## Focus Session — \(startStr)~\(endStr)\n"
        entry += "**Task:** \(taskName)\n"
        entry += "**Duration:** \(minutes)m\n"
        if let note = session.note, !note.isEmpty {
            entry += "**Notes:** \(note)\n"
        }

        noteFileManager.appendToTodayNote(content: entry)
    }

    // MARK: - Session Note Save

    func saveSessionNote(_ text: String) {
        guard let session = completedSessionForNote else { return }
        session.note = text
        dataController.save()
        // Re-append with the note included
        if !text.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let noteEntry = "**Notes:** \(text)\n"
            noteFileManager.appendToTodayNote(content: noteEntry)
        }
        showSessionNote = false
        completedSessionForNote = nil
    }

    func dismissSessionNote() {
        showSessionNote = false
        completedSessionForNote = nil
    }

    // MARK: - Meeting Conflict Detection

    private func checkMeetingConflicts() {
        let sessionEndTime = Date().addingTimeInterval(TimeInterval(totalSeconds))
        let warningWindow: TimeInterval = 3 * 60 // 3 minutes

        let now = Date()
        let checkEnd = sessionEndTime.addingTimeInterval(warningWindow)

        guard let events = try? dataController.fetchEvents(from: now, to: checkEnd) else { return }

        for event in events where !event.isAllDay {
            let timeUntilEvent = event.startDate.timeIntervalSince(now)
            if timeUntilEvent > 0 {
                let warningTime = max(1, Int(timeUntilEvent - warningWindow))
                notificationManager.scheduleMeetingConflictWarning(
                    eventTitle: event.title,
                    afterSeconds: warningTime
                )
                break // Only warn about the nearest event
            }
        }
    }

    // MARK: - Data Retention

    func pruneOldSessions() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) else { return }
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.isCompleted == true && session.startTime < cutoff
            }
        )
        guard let oldSessions = try? dataController.mainContext.fetch(descriptor) else { return }
        for session in oldSessions {
            dataController.mainContext.delete(session)
        }
        if !oldSessions.isEmpty {
            dataController.save()
        }
    }

    // MARK: - Helpers

    private func elapsedActiveSeconds() -> Int {
        guard let start = sessionStartTime else { return 0 }
        var pauseTime = accumulatedPauseSeconds
        if timerState == .paused, let pauseStart = pauseStartTime {
            pauseTime += Date().timeIntervalSince(pauseStart)
        }
        return Int(Date().timeIntervalSince(start) - pauseTime)
    }

    private func stopWithoutSaving() {
        stopTimer()
        if let session = currentSession {
            let elapsed = elapsedActiveSeconds()
            if elapsed < minimumSessionSeconds {
                dataController.mainContext.delete(session)
                dataController.save()
            } else {
                session.markCompleted()
                updateLinkedTaskStats(durationSeconds: session.durationSeconds)
                sessionCount += 1
                dataController.save()
            }
        }
        currentSession = nil
        linkedTask = nil
        sessionStartTime = nil
        pauseStartTime = nil
        accumulatedPauseSeconds = 0
    }

    private func resetState() {
        stopTimer()
        timerState = .idle
        remainingSeconds = 0
        totalSeconds = 0
        currentSession = nil
        linkedTask = nil
        sessionStartTime = nil
        pauseStartTime = nil
        accumulatedPauseSeconds = 0
    }

    // MARK: - Session Recovery

    private func recoverActiveSession() {
        guard let active = try? dataController.fetchActiveFocusSession() else { return }
        let elapsed = Int(Date().timeIntervalSince(active.startTime))
        let workDuration = settings.pomodoroWorkDuration * 60

        if elapsed >= workDuration {
            // Session expired while app was closed — mark complete
            active.markCompleted(endTime: active.startTime.addingTimeInterval(TimeInterval(workDuration)))
            dataController.save()
        } else {
            // Resume the session
            currentSession = active
            sessionStartTime = active.startTime
            totalSeconds = workDuration
            remainingSeconds = workDuration - elapsed
            accumulatedPauseSeconds = 0
            timerState = .running

            // Try to find linked task
            if let taskId = active.taskId {
                let descriptor = FetchDescriptor<MadoTask>(
                    predicate: #Predicate { task in
                        task.id == taskId && task.isDeleted == false
                    }
                )
                linkedTask = try? dataController.mainContext.fetch(descriptor).first
            }

            startTimer()
        }
    }

    // MARK: - Today Stats

    var todaySessionCount: Int {
        (try? dataController.fetchFocusSessions(for: Date()))?.count ?? 0
    }

    var todayFocusMinutes: Int {
        let sessions = (try? dataController.fetchFocusSessions(for: Date())) ?? []
        return sessions.reduce(0) { $0 + max(1, $1.durationSeconds / 60) }
    }
}

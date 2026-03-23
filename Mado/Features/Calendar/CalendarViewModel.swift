import Foundation
import SwiftUI

enum CalendarViewMode: String, CaseIterable {
    case monthly
    case weekly
    case daily

    var label: String {
        switch self {
        case .monthly: return "M"
        case .weekly: return "W"
        case .daily: return "D"
        }
    }

    var fullLabel: String {
        switch self {
        case .monthly: return "Month"
        case .weekly: return "Week"
        case .daily: return "Day"
        }
    }
}

@MainActor
@Observable
final class CalendarViewModel {
    enum NavigationDirection {
        case forward
        case backward
        case none
    }
    
    var navigationDirection: NavigationDirection = .none
    var events: [CalendarEvent] = []
    var calendarColorMap: [String: Color] = [:]
    var selectedDate = Date()
    var viewMode: CalendarViewMode = CalendarViewMode(rawValue: AppSettings.shared.defaultViewMode) ?? .weekly
    var selectedEvent: CalendarEvent?
    var isLoading = false
    var editingEvent: CalendarEvent?


    // Zoom control
    var hourHeight: CGFloat = 48  // Default smaller than 60
    private let minHourHeight: CGFloat = 24
    private let maxHourHeight: CGFloat = 96

    func zoomIn() {
        hourHeight = min(hourHeight + 8, maxHourHeight)
    }

    func zoomOut() {
        hourHeight = max(hourHeight - 8, minHourHeight)
    }

    var isCreatingEvent = false
    var creationIsAllDay = false
    var newEventTitle = ""
    var newEventStartDate: Date?
    var creationSlotHour: Int = 0
    var creationSlotDate: Date = Date()
    var newEventEndDate: Date?

    var isDragCreating = false
    var dragStartMinute: Int = 0
    var dragEndMinute: Int = 0
    var dragDate: Date = Date()



    // Event move (drag-to-move)
    var movingEvent: CalendarEvent?
    var moveStartY: CGFloat = 0
    var moveCurrentY: CGFloat = 0
    var movingColumnDate: Date = Date()
    var isMovingEvent: Bool { movingEvent != nil }

    enum ResizeEdge { case top, bottom }
    var resizingEvent: CalendarEvent?
    var resizeEdge: ResizeEdge = .bottom
    var resizeStartY: CGFloat = 0
    var resizeCurrentY: CGFloat = 0
    var isResizingEvent: Bool { resizingEvent != nil }


    // Guest move confirmation
    var showMoveGuestAlert = false
    var pendingMoveEvent: CalendarEvent?
    var pendingMoveStart: Date?
    var pendingMoveEnd: Date?

    // Hover time tooltip
    var isHoveringGrid = false
    var hoverY: CGFloat = 0
    var hoverColumnDate: Date = Date()

    var hoverTimeText: String {
        let totalMinutes = Int(hoverY / hourHeight * 60)
        let snapped = (totalMinutes / 30) * 30
        let hour = max(0, min(snapped / 60, 23))
        let minute = snapped % 60
        if AppSettings.shared.use24HourTime {
            return String(format: "%02d:%02d", hour, minute)
        }
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "am" : "pm"
        if minute == 0 {
            return "\(h) \(ampm)"
        } else {
            return "\(h):30 \(ampm)"
        }
    }

    var hoverTimeDetailText: String {
        let tz = TimeZone.current
        let abbrev = tz.abbreviation() ?? ""
        return "\(hoverTimeText) \(abbrev)"
    }

    var hoverSnappedY: CGFloat {
        let totalMinutes = Int(hoverY / hourHeight * 60)
        let snapped = (totalMinutes / 30) * 30
        return CGFloat(snapped) / 60.0 * hourHeight
    }
    private let data = DataController.shared
    private let sync = SyncEngine.shared
    private let calService = GoogleCalendarService()
    private let undo = UndoEngine.shared
    private let notifications = NotificationManager.shared

    private func accountEmail(for calendarId: String) -> String {
        if let cal = try? data.fetchCalendars().first(where: { $0.googleCalendarId == calendarId }) {
            return cal.accountEmail
        }
        return AuthenticationManager.shared.primaryAccount?.email ?? ""
    }

    // MARK: - Date Calculations

    var currentWeekDates: [Date] {
        var cal = Calendar.current
        cal.firstWeekday = AppSettings.shared.startOfWeek
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        let dates = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekInterval.start) }
        if !AppSettings.shared.showWeekends {
            return dates.filter { !cal.isDateInWeekend($0) }
        }
        return dates
    }

    var currentMonthGrid: [[Date]] {
        let cal = Calendar.current
        guard let monthInterval = cal.dateInterval(of: .month, for: selectedDate),
              let firstWeek = cal.dateInterval(of: .weekOfMonth, for: monthInterval.start) else { return [] }

        var rows: [[Date]] = []
        var current = firstWeek.start
        while rows.count < 6 {
            var week: [Date] = []
            for _ in 0..<7 {
                week.append(current)
                current = cal.date(byAdding: .day, value: 1, to: current)!
            }
            rows.append(week)
            if current > monthInterval.end && rows.count >= 4 { break }
        }
        return rows
    }

    var isInCurrentMonth: (Date) -> Bool {
        let cal = Calendar.current
        let month = cal.component(.month, from: selectedDate)
        let year = cal.component(.year, from: selectedDate)
        return { date in
            cal.component(.month, from: date) == month && cal.component(.year, from: date) == year
        }
    }

    var dayHours: [Int] { Array(0..<24) }

    var headerTitle: String {
        let fmt = DateFormatter()
        switch viewMode {
        case .monthly:
            fmt.dateFormat = "MMMM yyyy"
            return fmt.string(from: selectedDate)
        case .weekly:
            let dates = currentWeekDates
            guard let first = dates.first, let last = dates.last else { return "" }
            let mf = DateFormatter()
            mf.dateFormat = "MMMM yyyy"
            if Calendar.current.component(.month, from: first) == Calendar.current.component(.month, from: last) {
                return mf.string(from: first)
            }
            let sf = DateFormatter()
            sf.dateFormat = "MMM"
            return "\(sf.string(from: first)) – \(sf.string(from: last)) \(Calendar.current.component(.year, from: last))"
        case .daily:
            fmt.dateFormat = "EEEE, MMMM d, yyyy"
            return fmt.string(from: selectedDate)
        }
    }

    var currentTimeYOffset: CGFloat {
        let cal = Calendar.current
        let hour = CGFloat(cal.component(.hour, from: Date()))
        let minute = CGFloat(cal.component(.minute, from: Date()))
        return (hour + minute / 60.0) * hourHeight
    }

    var isCurrentWeek: Bool {
        currentWeekDates.contains { Calendar.current.isDateInToday($0) }
    }

    // MARK: - Data Loading

    private var cachedSelectedIds: [String] = []
    private var cachedPrimaryId: String = "primary"
    private var lastCalendarCacheTime: Date = .distantPast

    func reloadCalendarCache() {
        lastCalendarCacheTime = Date()
        cachedSelectedIds = (try? data.fetchSelectedCalendarIds()) ?? []
        cachedPrimaryId = sync.primaryCalendarId()
        let calendars = (try? data.fetchCalendars()) ?? []
        var colorMap: [String: Color] = [:]
        for cal in calendars {
            colorMap[cal.googleCalendarId] = cal.displayColor
        }
        calendarColorMap = colorMap
    }

    func loadEvents() {
        isLoading = true
        do {
            if cachedSelectedIds.isEmpty || Date().timeIntervalSince(lastCalendarCacheTime) > 30 {
                reloadCalendarCache()
            }

            let cal = Calendar.current
            let start: Date
            let end: Date
            switch viewMode {
            case .monthly:
                let grid = currentMonthGrid
                start = grid.first?.first ?? selectedDate
                end = cal.date(byAdding: .day, value: 1, to: grid.last?.last ?? selectedDate)!
            case .weekly:
                #if os(iOS)
                start = cal.startOfDay(for: selectedDate)
                end = cal.date(byAdding: .day, value: 7, to: start)!
                #else
                let dates = currentWeekDates
                start = dates.first ?? selectedDate
                end = cal.date(byAdding: .day, value: 1, to: dates.last ?? selectedDate)!
                #endif
            case .daily:
                start = cal.startOfDay(for: selectedDate)
                end = cal.date(byAdding: .day, value: 1, to: start)!
            }

            let allCalendarEvents = try data.fetchEvents(from: start, to: end, calendarIds: cachedSelectedIds)
            let calendarEvents = allCalendarEvents.filter { $0.sourceTaskId == nil }
            let allTasks = try data.fetchTasks(includeCompleted: false)
            let taskEvents = allTasks.compactMap { task -> CalendarEvent? in
                guard !task.isCompleted,
                      let dueDate = task.dueDate,
                      dueDate >= start, dueDate <= end else { return nil }
                return CalendarEvent(
                    googleEventId: "task-\(task.id)",
                    calendarId: cachedPrimaryId,
                    title: task.title,
                    startDate: dueDate,
                    endDate: Calendar.current.date(byAdding: .minute, value: 30, to: dueDate)!,
                    isAllDay: false,
                    sourceTaskId: task.id
                )
            }
            events = calendarEvents + taskEvents
        } catch {
            events = []
        }
        isLoading = false
    }

    func scheduleNotificationsForVisibleEvents() {
        let calendarEvents = events.filter { $0.sourceTaskId == nil }
        notifications.rescheduleAllEventReminders(calendarEvents)
        let briefTasks = (try? DataController.shared.fetchTasks()) ?? []
        notifications.scheduleMorningBrief(events: calendarEvents, tasks: briefTasks)
    }

    // MARK: - Event Queries


    func colorForEvent(_ event: CalendarEvent) -> Color {
        calendarColorMap[event.calendarId] ?? MadoColors.calendarDefault
    }

    func eventsForDate(_ date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        return events.filter { cal.isDate($0.startDate, inSameDayAs: date) }
    }

    func timedEvents(for date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        return events.filter { !$0.isAllDay && cal.isDate($0.startDate, inSameDayAs: date) }
    }

    func eventsForHour(_ hour: Int, on date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        return events.filter { event in
            guard !event.isAllDay else { return false }
            return cal.isDate(event.startDate, inSameDayAs: date) && cal.component(.hour, from: event.startDate) == hour
        }
    }

    func allDayEvents(for date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        return events.filter { $0.isAllDay && cal.isDate($0.startDate, inSameDayAs: date) }
    }

    func eventTopOffset(for event: CalendarEvent) -> CGFloat {
        let cal = Calendar.current
        let hour = CGFloat(cal.component(.hour, from: event.startDate))
        let minute = CGFloat(cal.component(.minute, from: event.startDate))
        return (hour + minute / 60.0) * hourHeight
    }

    func eventHeight(for event: CalendarEvent) -> CGFloat {
        let minutes = CGFloat(event.durationMinutes)
        let height = (minutes / 60.0) * hourHeight
        return max(height, MadoTheme.Layout.eventBlockMinHeight)
    }

    // MARK: - Navigation

    func navigateForward() {
        navigationDirection = .forward
        let cal = Calendar.current
        switch viewMode {
        case .monthly: selectedDate = cal.date(byAdding: .month, value: 1, to: selectedDate)!
        case .weekly: selectedDate = cal.date(byAdding: .weekOfYear, value: 1, to: selectedDate)!
        case .daily: selectedDate = cal.date(byAdding: .day, value: 1, to: selectedDate)!
        }
        loadEvents()
    }

    func navigateBack() {
        navigationDirection = .backward
        let cal = Calendar.current
        switch viewMode {
        case .monthly: selectedDate = cal.date(byAdding: .month, value: -1, to: selectedDate)!
        case .weekly: selectedDate = cal.date(byAdding: .weekOfYear, value: -1, to: selectedDate)!
        case .daily: selectedDate = cal.date(byAdding: .day, value: -1, to: selectedDate)!
        }
        loadEvents()
    }

    func goToToday() {
        let now = Date()
        let cal = Calendar.current
        
        let isSameDay = cal.isDate(now, inSameDayAs: selectedDate)
        if !isSameDay {
            navigationDirection = now > selectedDate ? .forward : .backward
        } else {
            navigationDirection = .none
        }
        
        selectedDate = now
        loadEvents()
    }

    func selectDate(_ date: Date) {
        navigationDirection = .none
        selectedDate = date
        viewMode = .daily
        loadEvents()
    }

    // MARK: - Event Creation

    func updateEvent(_ event: CalendarEvent, title: String, startDate: Date, endDate: Date, location: String?, notes: String?, isAllDay: Bool) {
        let snapshot = EventSnapshot(from: event)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.isAllDay = isAllDay
        event.needsSync = true
        event.localUpdatedAt = Date()
        data.save()
        editingEvent = nil
        loadEvents()
        sync.schedulePush()
        undo.recordEventEdited(event, snapshot: snapshot)
        notifications.scheduleEventReminder(event)
    }

    func createEventWithDetails(title: String, startDate: Date, endDate: Date, location: String?, notes: String?, isAllDay: Bool, guestEmails: [String]? = nil, addMeetLink: Bool = false) {
        let calendarId = sync.primaryCalendarId()
        let event = CalendarEvent(
            googleEventId: "",
            calendarId: calendarId,
            title: title,
            notes: notes,
            location: location,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            accountEmail: accountEmail(for: calendarId)
        )
        // Set attendees from guest emails
        if let emails = guestEmails, !emails.isEmpty {
            let attendees = emails.map { EventAttendee(email: $0, displayName: nil, responseStatus: "needsAction", isOrganizer: false, isSelf: false) }
            event.attendeesJSON = try? JSONEncoder().encode(attendees)
        }
        // Mark for Google Meet link creation (actual URL comes back from Google after push)
        if addMeetLink {
            event.conferenceName = "Google Meet"
            event.conferenceURL = "pending-meet-creation"
        }
        event.needsSync = true
        data.createEvent(event)
        cancelEventCreation()
        loadEvents()
        sync.schedulePush()
        undo.recordEventCreated(event)
        notifications.scheduleEventReminder(event)
    }

    func beginEventCreation(hour: Int, date: Date) {
        editingEvent = nil
        let cal = Calendar.current
        creationSlotHour = hour
        creationSlotDate = date
        newEventStartDate = cal.date(bySettingHour: hour, minute: 0, second: 0, of: date)
        newEventTitle = ""
        isCreatingEvent = true
    }

    func commitEventCreation() {
        let trimmed = newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let startDate = newEventStartDate else {
            cancelEventCreation()
            return
        }

        let cal = Calendar.current
        let endDate = cal.date(byAdding: .minute, value: AppSettings.shared.defaultEventDuration, to: startDate)!
        let calendarId = sync.primaryCalendarId()

        let event = CalendarEvent(
            googleEventId: "",
            calendarId: calendarId,
            title: trimmed,
            startDate: startDate,
            endDate: endDate,
            accountEmail: accountEmail(for: calendarId)
        )
        event.needsSync = true
        data.createEvent(event)
        cancelEventCreation()
        loadEvents()
        sync.schedulePush()
        undo.recordEventCreated(event)
        notifications.scheduleEventReminder(event)
    }

    func cancelEventCreation() {
        isCreatingEvent = false
        newEventTitle = ""
        newEventStartDate = nil
        newEventEndDate = nil
        isDragCreating = false
    }

    func createEventFromParsed(_ parsed: ParsedEvent) {
        let cal = Calendar.current
        let startDate = parsed.startDate ?? Date()
        let endDate = parsed.endDate ?? cal.date(byAdding: .minute, value: AppSettings.shared.defaultEventDuration, to: startDate)!
        let calendarId = sync.primaryCalendarId()

        let event = CalendarEvent(
            googleEventId: "",
            calendarId: calendarId,
            title: parsed.title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: parsed.isAllDay,
            accountEmail: accountEmail(for: calendarId)
        )
        event.needsSync = true
        data.createEvent(event)
        loadEvents()
        sync.schedulePush()
        undo.recordEventCreated(event)
        notifications.scheduleEventReminder(event)
    }


    /// Schedule a task onto the calendar by setting its dueDate.
    /// Does NOT create a CalendarEvent — tasks stay as tasks.
    func scheduleTask(taskId: String, at date: Date) {
        if let task = try? data.fetchTasks().first(where: { $0.id == taskId }) {
            task.dueDate = date
            task.markUpdated()
            data.save()
        }
        selectedDate = date
        loadEvents()
        sync.schedulePush()
    }

    // MARK: - Task Drop (30-min blocks)
    func handleTaskDrop(_ transferable: TransferableTask, at date: Date) {
        // Only update the task’s dueDate — no CalendarEvent creation
        scheduleTask(taskId: transferable.id, at: date)
    }

    func deleteEvent(_ event: CalendarEvent) {
        print("[CalVM] deleteEvent '\(event.title)' googleId=\(event.googleEventId) recurringId=\(event.recurringEventId ?? "nil") calId=\(event.calendarId)")
        undo.recordEventDeleted(event)
        notifications.cancelEventReminder(event)

        if let seriesId = event.recurringEventId {
            data.deleteEventSeries(recurringEventId: seriesId)

            let parentEvent = CalendarEvent(
                googleEventId: seriesId,
                calendarId: event.calendarId,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                accountEmail: event.accountEmail
            )
            parentEvent.isDeleted = true
            parentEvent.needsSync = true
            data.createEvent(parentEvent)
        } else {
            event.isDeleted = true
            event.needsSync = true
            event.localUpdatedAt = Date()
            data.save()
        }

        loadEvents()
        sync.schedulePush()
    }

    var isRecurringEvent: (CalendarEvent) -> Bool = { event in
        event.recurringEventId != nil && !event.recurringEventId!.isEmpty
    }

    func rsvpToEvent(_ event: CalendarEvent, response: String, applyToSeries: Bool = false) {
        let previousJSON = event.attendeesJSON
        var attendees = event.attendees
        guard let selfIndex = attendees.firstIndex(where: { $0.isSelf }) else { return }

        let updatedAttendee = EventAttendee(
            email: attendees[selfIndex].email,
            displayName: attendees[selfIndex].displayName,
            responseStatus: response,
            isOrganizer: attendees[selfIndex].isOrganizer,
            isSelf: true
        )
        attendees[selfIndex] = updatedAttendee
        event.attendeesJSON = try? JSONEncoder().encode(attendees)
        event.localUpdatedAt = Date()

        if applyToSeries, let seriesId = event.recurringEventId {
            let allInstances = (try? data.fetchEventsBySeries(recurringEventId: seriesId)) ?? []
            for instance in allInstances where instance.id != event.id {
                var instAttendees = instance.attendees
                if let idx = instAttendees.firstIndex(where: { $0.isSelf }) {
                    instAttendees[idx] = EventAttendee(
                        email: instAttendees[idx].email,
                        displayName: instAttendees[idx].displayName,
                        responseStatus: response,
                        isOrganizer: instAttendees[idx].isOrganizer,
                        isSelf: true
                    )
                    instance.attendeesJSON = try? JSONEncoder().encode(instAttendees)
                    instance.localUpdatedAt = Date()
                }
            }
        }

        data.save()
        undo.recordRSVPChanged(event, previousJSON: previousJSON)

        let targetEventId = applyToSeries ? (event.recurringEventId ?? event.googleEventId) : event.googleEventId
        let dtos = attendees.map {
            GoogleAttendeeDTO(
                email: $0.email,
                displayName: $0.displayName,
                responseStatus: $0.responseStatus,
                organizer: $0.isOrganizer,
                self: $0.isSelf
            )
        }
        Task {
            do {
                _ = try await calService.rsvpEvent(
                    calendarId: event.calendarId,
                    eventId: targetEventId,
                    attendees: dtos
                )
            } catch {
                await MainActor.run { loadEvents() }
            }
        }
    }

    // MARK: - Overlapping Event Layout

    func columnLayoutForEvents(on date: Date) -> [EventColumnInfo] {
        let events = timedEvents(for: date)
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                return $0.endDate > $1.endDate  // longer events first for ties
            }
        guard !events.isEmpty else { return [] }

        var columnEnds: [Date] = []
        var assignments: [(event: CalendarEvent, column: Int)] = []

        for event in events {
            var assignedCol = -1
            for (i, end) in columnEnds.enumerated() {
                if end <= event.startDate {
                    assignedCol = i
                    columnEnds[i] = event.endDate
                    break
                }
            }
            if assignedCol == -1 {
                assignedCol = columnEnds.count
                columnEnds.append(event.endDate)
            }
            assignments.append((event, assignedCol))
        }

        return assignments.map { (event, col) in
            let maxCol = assignments
                .filter { event.startDate < $0.event.endDate && $0.event.startDate < event.endDate }
                .map(\.column)
                .max() ?? col
            return EventColumnInfo(id: event.id, event: event, column: col, totalColumns: maxCol + 1)
        }
    }

    // MARK: - Drag to Create

    func beginDragCreation(date: Date, startY: CGFloat) {
        editingEvent = nil
        let minute = Int(startY / hourHeight * 60)
        let snapped = (minute / 30) * 30
        isDragCreating = true
        dragDate = date
        dragStartMinute = snapped
        dragEndMinute = snapped + 30
    }

    func updateDragCreation(currentY: CGFloat) {
        let minute = Int(max(0, min(currentY, hourHeight * 24)) / hourHeight * 60)
        let snapped = ((minute + 15) / 30) * 30
        dragEndMinute = max(0, min(snapped, 24 * 60))
    }

    func finishDragCreation() {
        guard isDragCreating else { return }
        isDragCreating = false

        let actualStart = min(dragStartMinute, dragEndMinute)
        var actualEnd = max(dragStartMinute, dragEndMinute)
        if actualEnd - actualStart < 30 { actualEnd = actualStart + AppSettings.shared.defaultEventDuration }

        let cal = Calendar.current
        guard let startDate = cal.date(bySettingHour: actualStart / 60, minute: actualStart % 60, second: 0, of: dragDate),
              let endDate = cal.date(bySettingHour: min(actualEnd / 60, 23), minute: actualEnd % 60, second: 0, of: dragDate) else { return }

        newEventStartDate = startDate
        newEventEndDate = endDate
        creationSlotHour = actualStart / 60
        creationSlotDate = dragDate
        newEventTitle = ""
        isCreatingEvent = true
    }

    var dragPreviewTopOffset: CGFloat {
        let topMinute = min(dragStartMinute, dragEndMinute)
        return CGFloat(topMinute) / 60.0 * hourHeight
    }

    var dragPreviewHeight: CGFloat {
        let diff = abs(dragEndMinute - dragStartMinute)
        return max(CGFloat(diff) / 60.0 * hourHeight, hourHeight / 4)
    }


    // MARK: - Drag to Move Event

    /// Y offset of the moving event's ghost relative to its original position
    var moveOffsetY: CGFloat {
        moveCurrentY - moveStartY
    }

    /// Snapped minute position for the moving event's new start time
    var movingEventSnappedMinute: Int {
        guard let event = movingEvent else { return 0 }
        let cal = Calendar.current
        let originalMinute = cal.component(.hour, from: event.startDate) * 60 + cal.component(.minute, from: event.startDate)
        let deltaMinutes = Int(moveOffsetY / hourHeight * 60)
        let newMinute = originalMinute + deltaMinutes
        let snapped = ((newMinute + 15) / 30) * 30
        return max(0, min(snapped, 24 * 60 - 30))
    }

    /// Top offset for the moving event ghost
    var movingEventTopOffset: CGFloat {
        CGFloat(movingEventSnappedMinute) / 60.0 * hourHeight
    }

    func beginEventMove(_ event: CalendarEvent, startY: CGFloat) {
        // Don't move all-day events
        guard !event.isAllDay else { return }
        editingEvent = nil
        cancelEventCreation()
        movingEvent = event
        moveStartY = startY
        moveCurrentY = startY
        movingColumnDate = event.startDate
    }
    func updateEventMove(currentY: CGFloat) {
        guard movingEvent != nil else { return }
        moveCurrentY = currentY
    }
    func updateEventMoveColumn(date: Date) {
        guard movingEvent != nil else { return }
        movingColumnDate = date
    }
    func finishEventMove() {
        guard let event = movingEvent else { return }
        guard event.canEditTime else {
            movingEvent = nil
            return
        }
        let newStartMinute = movingEventSnappedMinute
        let duration = event.durationMinutes
        let cal = Calendar.current
        let targetDate = cal.startOfDay(for: movingColumnDate)
        guard let newStart = cal.date(bySettingHour: newStartMinute / 60, minute: newStartMinute % 60, second: 0, of: targetDate),
              let newEnd = cal.date(byAdding: .minute, value: duration, to: newStart) else {
            movingEvent = nil
            return
        }
        guard newStart != event.startDate else {
            movingEvent = nil
            return
        }
            if let taskId = event.sourceTaskId {
            // Task pseudo-event: update the underlying task's dueDate
            scheduleTask(taskId: taskId, at: newStart)
            movingEvent = nil
        } else if !event.attendees.isEmpty {
            // Event has guests — ask user for confirmation before applying
            pendingMoveEvent = event
            pendingMoveStart = newStart
            pendingMoveEnd = newEnd
            showMoveGuestAlert = true
            movingEvent = nil
        } else {
            // No guests — apply immediately
            applyEventMove(event: event, newStart: newStart, newEnd: newEnd)
            movingEvent = nil
        }
    }

    /// Apply the move and schedule a push. `sendUpdates` controls guest notification:
    /// "all" = notify all guests, "none" = don't notify.
    func confirmEventMove(sendNotifications: Bool) {
        guard let event = pendingMoveEvent,
              let newStart = pendingMoveStart,
              let newEnd = pendingMoveEnd else {
            cancelPendingMove()
            return
        }
        let sendUpdates = sendNotifications ? "all" : "none"
        applyEventMove(event: event, newStart: newStart, newEnd: newEnd, sendUpdates: sendUpdates)
        cancelPendingMove()
    }

    func cancelPendingMove() {
        pendingMoveEvent = nil
        pendingMoveStart = nil
        pendingMoveEnd = nil
        showMoveGuestAlert = false
    }

    private func applyEventMove(event: CalendarEvent, newStart: Date, newEnd: Date, sendUpdates: String? = nil) {
        let snapshot = EventSnapshot(from: event)
        event.startDate = newStart
        event.endDate = newEnd
        event.needsSync = true
        event.localUpdatedAt = Date()
        if let sendUpdates {
            sync.sendUpdatesOverrides[event.googleEventId] = sendUpdates
        }
        data.save()
        loadEvents()
        sync.schedulePush()
        undo.recordEventEdited(event, snapshot: snapshot)
    }
    func cancelEventMove() {
        movingEvent = nil
    }

    // MARK: - Event Resize

    func beginEventResize(_ event: CalendarEvent, edge: ResizeEdge, startY: CGFloat) {
        guard !event.isAllDay else { return }
        editingEvent = nil
        cancelEventCreation()
        resizingEvent = event
        resizeEdge = edge
        resizeStartY = startY
        resizeCurrentY = startY
    }

    func updateEventResize(currentY: CGFloat) {
        guard resizingEvent != nil else { return }
        resizeCurrentY = currentY
    }

    var resizingSnappedMinute: Int {
        let rawMinute = Int(max(0, min(resizeCurrentY, hourHeight * 24)) / hourHeight * 60)
        return ((rawMinute + 7) / 15) * 15
    }

    var resizingEventTopOffset: CGFloat {
        guard let event = resizingEvent else { return 0 }
        let cal = Calendar.current
        let originalStartMinute = cal.component(.hour, from: event.startDate) * 60 + cal.component(.minute, from: event.startDate)
        let originalEndMinute = cal.component(.hour, from: event.endDate) * 60 + cal.component(.minute, from: event.endDate)

        if resizeEdge == .top {
            let newStart = min(resizingSnappedMinute, originalEndMinute - 15)
            return CGFloat(newStart) / 60.0 * hourHeight
        } else {
            return CGFloat(originalStartMinute) / 60.0 * hourHeight
        }
    }

    var resizingEventHeight: CGFloat {
        guard let event = resizingEvent else { return 0 }
        let cal = Calendar.current
        let originalStartMinute = cal.component(.hour, from: event.startDate) * 60 + cal.component(.minute, from: event.startDate)
        let originalEndMinute = cal.component(.hour, from: event.endDate) * 60 + cal.component(.minute, from: event.endDate)

        let minutes: Int
        if resizeEdge == .top {
            let newStart = min(resizingSnappedMinute, originalEndMinute - 15)
            minutes = originalEndMinute - newStart
        } else {
            let newEnd = max(resizingSnappedMinute, originalStartMinute + 15)
            minutes = newEnd - originalStartMinute
        }
        return max(CGFloat(minutes) / 60.0 * hourHeight, hourHeight / 4)
    }

    func finishEventResize() {
        guard let event = resizingEvent else { return }
        guard event.canEditTime else {
            resizingEvent = nil
            return
        }
        let cal = Calendar.current
        let originalStartMinute = cal.component(.hour, from: event.startDate) * 60 + cal.component(.minute, from: event.startDate)
        let originalEndMinute = cal.component(.hour, from: event.endDate) * 60 + cal.component(.minute, from: event.endDate)
        let dayStart = cal.startOfDay(for: event.startDate)

        let newStartMinute: Int
        let newEndMinute: Int
        if resizeEdge == .top {
            newStartMinute = min(resizingSnappedMinute, originalEndMinute - 15)
            newEndMinute = originalEndMinute
        } else {
            newStartMinute = originalStartMinute
            newEndMinute = max(resizingSnappedMinute, originalStartMinute + 15)
        }

        guard newStartMinute != originalStartMinute || newEndMinute != originalEndMinute,
              let newStart = cal.date(bySettingHour: newStartMinute / 60, minute: newStartMinute % 60, second: 0, of: dayStart),
              let newEnd = cal.date(bySettingHour: newEndMinute / 60, minute: newEndMinute % 60, second: 0, of: dayStart) else {
            resizingEvent = nil
            return
        }

        if let taskId = event.sourceTaskId {
            scheduleTask(taskId: taskId, at: newStart)
            resizingEvent = nil
        } else {
            applyEventMove(event: event, newStart: newStart, newEnd: newEnd)
            resizingEvent = nil
        }
    }

    // MARK: - Convert Event to Task

    func createTaskFromEvent(_ event: CalendarEvent) {
        let task = MadoTask(
            title: event.title,
            notes: event.notes,
            dueDate: event.startDate
        )
        data.createTask(task)
        // Reload so the task appears in task panel and as a task block on calendar
        loadEvents()
        sync.schedulePush()
    }
}

struct EventColumnInfo: Identifiable {
    let id: String
    let event: CalendarEvent
    let column: Int
    let totalColumns: Int
}
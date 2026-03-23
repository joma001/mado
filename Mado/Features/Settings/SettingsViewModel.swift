import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    var calendars: [UserCalendar] = []
    var isLoadingCalendars = false

    private let data = DataController.shared
    private let calendarService = GoogleCalendarService()

    func loadCalendars() {
        do {
            calendars = try data.fetchCalendars()
        } catch {
            calendars = []
        }
    }

    func toggleCalendar(_ calendar: UserCalendar) {
        calendar.isSelected.toggle()
        data.save()
        SyncEngine.shared.onSyncCompleted?()
    }

    func fetchRemoteCalendars() async {
        isLoadingCalendars = true
        defer { isLoadingCalendars = false }

        let accounts = AuthenticationManager.shared.accounts
        guard !accounts.isEmpty else { return }

        do {
            for account in accounts {
                let response = try await calendarService.listCalendars(accountEmail: account.email)
                guard let items = response.items else { continue }

                for remote in items {
                    if calendars.contains(where: { $0.googleCalendarId == remote.id }) {
                        continue
                    } else {
                        let cal = UserCalendar(
                            googleCalendarId: remote.id,
                            name: remote.summary ?? "Untitled",
                            colorHex: remote.backgroundColor?.replacingOccurrences(of: "#", with: "") ?? "4A90D9",
                            isSelected: remote.selected ?? (remote.primary ?? false),
                            isPrimary: remote.primary ?? false,
                            accessRole: remote.accessRole ?? "reader",
                            accountEmail: account.email
                        )
                        data.mainContext.insert(cal)
                    }
                }
            }
            data.save()
            loadCalendars()
        } catch {
            // Silently fail — user can retry
        }
    }

    func addAccount() async {
        await AuthenticationManager.shared.addAccount()
        await fetchRemoteCalendars()
    }

    func removeAccount(_ email: String) {
        let calendarsToRemove = calendars.filter { $0.accountEmail == email }
        for cal in calendarsToRemove {
            data.mainContext.delete(cal)
        }
        data.save()
        AuthenticationManager.shared.removeAccount(email)
        loadCalendars()
    }

    func setPrimaryAccount(_ email: String) {
        AuthenticationManager.shared.setPrimaryAccount(email)
    }

    func signOut() {
        SyncEngine.shared.stopPeriodicSync()
        AuthenticationManager.shared.signOut()
    }

    var writableCalendars: [UserCalendar] {
        calendars.filter { $0.accessRole == "owner" || $0.accessRole == "writer" }
    }
}

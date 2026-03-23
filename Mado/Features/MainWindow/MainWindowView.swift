import SwiftUI

struct MainWindowView: View {
    @State private var todoVM = TodoViewModel()
    @State private var calendarVM = CalendarViewModel()

    private let sync = SyncEngine.shared

    var body: some View {
        PlannerView(calendarVM: calendarVM, todoVM: todoVM)
            .onAppear {
                todoVM.loadTasks()
                todoVM.loadLabels()
                calendarVM.loadEvents()
                setupSyncCallback()
            }
            .onDisappear {
                sync.onSyncCompleted = nil
            }
    }

    private func setupSyncCallback() {
        let tvm = todoVM
        let cvm = calendarVM
        sync.onSyncCompleted = {
            tvm.loadTasks()
            cvm.reloadCalendarCache()
            cvm.loadEvents()
            cvm.scheduleNotificationsForVisibleEvents()
        }
    }
}

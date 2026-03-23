import SwiftUI

struct iOSMainTabView: View {
    @State private var selectedTab = 0
    @State private var showQuickAdd = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                iOSTodayTab()
                    .tabItem {
                        Label("Today", systemImage: "sun.max.fill")
                    }
                    .tag(0)

                iOSCalendarTab()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }
                    .tag(1)

                iOSTasksTab()
                    .tabItem {
                        Label("Tasks", systemImage: "checkmark.circle")
                    }
                    .tag(2)

                iOSInvitesTab()
                    .tabItem {
                        Label("Invites", systemImage: "envelope")
                    }
                    .tag(3)

                iOSSettingsTab()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(4)
            }

            // Floating quick-add button
            Button {
                showQuickAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(MadoColors.accent)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 80)
        }
        .overlay {
            UndoToastOverlay()
        }
        .sheet(isPresented: $showQuickAdd) {
            iOSQuickAddSheet()
                .presentationDetents([.medium])
        }
    }
}

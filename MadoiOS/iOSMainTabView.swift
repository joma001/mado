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
                    .accessibilityLabel("오늘")

                iOSCalendarTab()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }
                    .tag(1)
                    .accessibilityLabel("캘린더")

                iOSTasksTab()
                    .tabItem {
                        Label("Tasks", systemImage: "checkmark.circle")
                    }
                    .tag(2)
                    .accessibilityLabel("할 일")

                iOSInvitesTab()
                    .tabItem {
                        Label("Invites", systemImage: "envelope")
                    }
                    .tag(3)
                    .accessibilityLabel("초대")

                iOSSettingsTab()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(4)
                    .accessibilityLabel("설정")
            }

            // Floating quick-add button
            Button {
                showQuickAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(MadoColors.onAccent)
                    .frame(width: 56, height: 56)
                    .background(MadoColors.accent)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 80)
            .accessibilityLabel("빠른 추가")
            .accessibilityHint("할 일 또는 일정을 빠르게 추가합니다")
        }
        .overlay {
            UndoToastOverlay()
        }
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                SyncErrorBanner()
                DataStoreWarningBanner()
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            iOSQuickAddSheet()
                .presentationDetents([.medium])
        }
    }
}

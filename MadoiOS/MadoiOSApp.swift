import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct MadoiOSApp: App {
    private let dataController = DataController.shared
    private let authManager = AuthenticationManager.shared
    private let syncEngine = SyncEngine.shared

    var body: some Scene {
        WindowGroup {
            iOSRootView()
                .preferredColorScheme(.light)
                .modelContainer(dataController.modelContainer)
                .onOpenURL { url in
                    _ = authManager.handle(url: url)
                }
                .task {
                    await authManager.restorePreviousSignIn()
                    await NotificationManager.shared.requestAuthorization()
                    if authManager.status.isSignedIn {
                        await syncEngine.syncAll()
                        syncEngine.startPeriodicSync()
                    }
                }
                .onChange(of: authManager.status) { _, newStatus in
                    if newStatus.isSignedIn {
                        Task {
                            await syncEngine.syncAll()
                            syncEngine.startPeriodicSync()
                        }
                    } else {
                        syncEngine.stopPeriodicSync()
                    }
                }
        }
    }
}

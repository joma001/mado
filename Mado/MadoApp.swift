import SwiftUI
import SwiftData
import GoogleSignIn
import KeyboardShortcuts
import Carbon.HIToolbox

final class MadoAppDelegate: NSObject, NSApplicationDelegate {
    private let menuBarVM = MenuBarViewModel.shared
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure main window opens on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showMainWindow()
        }

        KeyboardShortcuts.onKeyUp(for: .togglePopover) { [weak self] in
            self?.toggleMenuBarPopover()
        }

        KeyboardShortcuts.onKeyUp(for: .joinNextMeeting) {
            Task { @MainActor in
                MenuBarViewModel.shared.joinNextMeeting()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .quickAddTask) {
            Task { @MainActor in
                QuickAddTaskWindow.shared.toggle()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .openApp) { [weak self] in
            Task { @MainActor in
                self?.showMainWindow()
            }
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKey(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleLocalKey(event) == true { return nil }
            return event
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let mainWindow = NSApp.windows.first(where: {
            $0.title == "mado" && !String(describing: type(of: $0)).contains("MenuBar")
                && !String(describing: type(of: $0)).contains("StatusBar")
        }) {
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    private func handleGlobalKey(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let keyCode = event.keyCode
        if mods == [.command] && keyCode == kVK_ANSI_Y {
            DispatchQueue.main.async { [weak self] in self?.toggleMenuBarPopover() }
        } else if mods == [.command] && keyCode == kVK_ANSI_J {
            DispatchQueue.main.async { MenuBarViewModel.shared.joinNextMeeting() }
        } else if mods == [.command] && keyCode == kVK_ANSI_0 {
            DispatchQueue.main.async { QuickAddTaskWindow.shared.toggle() }
        } else if mods == [.command, .shift] && keyCode == kVK_ANSI_P {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                for w in NSApp.windows where w.title == "mado" && !String(describing: type(of: w)).contains("MenuBar") {
                    w.makeKeyAndOrderFront(nil)
                    return
                }
            }
        }
    }

    private func handleLocalKey(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let keyCode = event.keyCode
        if mods == [.command] && keyCode == kVK_ANSI_Y {
            toggleMenuBarPopover()
            return true
        } else if mods == [.command] && keyCode == kVK_ANSI_J {
            Task { @MainActor in MenuBarViewModel.shared.joinNextMeeting() }
            return true
        } else if mods == [.command] && keyCode == kVK_ANSI_0 {
            Task { @MainActor in QuickAddTaskWindow.shared.toggle() }
            return true
        }
        return false
    }

    func toggleMenuBarPopover() {
        // Find our status-item button in the system status bar and simulate a click.
        // This triggers the same SwiftUI MenuBarExtra toggle as a real user click.
        for window in NSApp.windows {
            let className = String(describing: type(of: window))
            // NSStatusBarWindow hosts status-item buttons (menu bar icons)
            guard className.contains("NSStatusBarWindow") else { continue }
            if let button = findStatusButton(in: window.contentView) {
                button.performClick(nil)
                return
            }
        }
    }

    private func findStatusButton(in view: NSView?) -> NSStatusBarButton? {
        guard let view else { return nil }
        if let button = view as? NSStatusBarButton {
            return button
        }
        for subview in view.subviews {
            if let found = findStatusButton(in: subview) {
                return found
            }
        }
        return nil
    }
}

@main
struct MadoApp: App {
    @NSApplicationDelegateAdaptor(MadoAppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    private let dataController = DataController.shared
    private let authManager = AuthenticationManager.shared
    private let syncEngine = SyncEngine.shared

    var body: some Scene {
        WindowGroup("mado") {
            RootView()
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
        .defaultSize(width: 1100, height: 700)

        MenuBarExtra("mado", systemImage: "checkmark.circle.fill") {
            MenuBarPopoverView()
                .modelContainer(dataController.modelContainer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .modelContainer(dataController.modelContainer)
        }
    }
}

struct RootView: View {
    private let authManager = AuthenticationManager.shared

    var body: some View {
        Group {
            switch authManager.status {
            case .signedIn:
                MainWindowView()
            case .signingIn:
                LoadingOverlay(message: "Signing in...")
            case .error(let message):
                LoginView(errorMessage: message)
            default:
                LoginView()
            }
        }
        .overlay {
            UndoToastOverlay()
        }
        .frame(
            minWidth: MadoTheme.Layout.mainWindowMinWidth,
            minHeight: MadoTheme.Layout.mainWindowMinHeight
        )
    }
}

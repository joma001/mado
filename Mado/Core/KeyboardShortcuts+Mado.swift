import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePopover = Self("togglePopover", default: .init(.y, modifiers: [.command]))
    static let joinNextMeeting = Self("joinNextMeeting", default: .init(.j, modifiers: [.command]))
    static let quickAddTask = Self("quickAddTask", default: .init(.zero, modifiers: [.command]))
    static let openApp = Self("openApp", default: .init(.p, modifiers: [.command, .shift]))
}

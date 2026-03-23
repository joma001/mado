import Foundation
import SwiftUI

// MARK: - Cross-platform URL opening

func openExternalURL(_ url: URL) {
    #if os(macOS)
    NSWorkspace.shared.open(url)
    #elseif os(iOS)
    UIApplication.shared.open(url)
    #endif
}

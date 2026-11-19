import AppKit

extension Notification.Name {
    /// Posted when Dock re-activates Lyria with no visible windows.
    static let lyriaOpenMainWindow = Notification.Name("lyria.openMainWindow")
}

enum LyriaSceneID {
    static let main = "main"
}

/// Keeps the process (and menu bar extra) alive after the last window closes.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: .lyriaOpenMainWindow, object: nil)
        }
        return true
    }
}

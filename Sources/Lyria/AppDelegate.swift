import AppKit

extension Notification.Name {
    /// Posted when Dock re-activates Lyria with no visible windows (legacy fallback).
    static let lyriaOpenMainWindow = Notification.Name("lyria.openMainWindow")
}

enum LyriaSceneID {
    static let main = "main"
}

/// Keeps the process alive after the last window closes so system Now Playing can keep controlling playback.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Injected from the main `WindowGroup` via `openWindow`. Survives after the window is closed.
    var openMainWindow: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            if let openMainWindow {
                openMainWindow()
            } else {
                NotificationCenter.default.post(name: .lyriaOpenMainWindow, object: nil)
            }
        }
        return true
    }
}

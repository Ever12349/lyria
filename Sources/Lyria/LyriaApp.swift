import AppKit
import SwiftUI
import LyriaCore

struct LyriaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var playback = PlaybackRoot()

    var body: some Scene {
        WindowGroup(id: LyriaSceneID.main) {
            ContentView(store: playback.session)
                .environment(playback.transport)
                .environment(playback.queue)
                .background(OpenWindowBinder(appDelegate: appDelegate))
                .frame(
                    minWidth: LyriaTheme.windowMinimum.width,
                    maxWidth: .infinity,
                    minHeight: LyriaTheme.windowMinimum.height,
                    maxHeight: .infinity,
                    alignment: .top
                )
        }
        .defaultSize(width: 1180, height: 760)
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // Hidden for the system Now Playing slice — keep MenuBarPlayerView sources; do not delete.
        // MenuBarExtra {
        //     MenuBarPlayerView()
        //         .environmentObject(playback.session)
        //         .environment(playback.transport)
        //         .environment(playback.queue)
        // } label: {
        //     Image(systemName: "music.note")
        // }
        // .menuBarExtraStyle(.window)
    }
}

/// Binds Dock-reopen to `openWindow` without depending on MenuBarExtra.
private struct OpenWindowBinder: View {
    let appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                appDelegate.openMainWindow = {
                    openWindow(id: LyriaSceneID.main)
                }
            }
    }
}

/// One engine, one transport mirror, one session. Created with the process.
@MainActor
final class PlaybackRoot {
    let transport: TransportState
    let queue: PlaybackQueueState
    let session: AppSession
    private var terminateObserver: NSObjectProtocol?

    init() {
        let prefs = PlaybackPreferenceStore.load()
        let transport = TransportState()
        transport.shuffle = prefs.shuffle
        transport.repeatMode = prefs.repeatMode
        transport.volume = prefs.volume
        let queue = PlaybackQueueState()
        let engine = PlaybackEngine(
            preferences: prefs,
            persist: { PlaybackPreferenceStore.save($0) },
            persistSession: { PlaybackSessionStore.save($0) }
        )
        self.transport = transport
        self.queue = queue
        let session = AppSession(engine: engine, transport: transport, queueState: queue)
        self.session = session
        let cache = engine.sessionCache
        let systemNowPlaying = engine.systemNowPlaying
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            systemNowPlaying.clear()
            cache.flush()
            MainActor.assumeIsolated {
                session.persistUINow()
            }
        }
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }
}

enum PlaybackPreferenceStore {
    private static let key = "lyria.playbackPreferences"

    static func load() -> PlaybackPreferences {
        guard let data = UserDefaults.standard.data(forKey: key) else { return .default }
        return (try? JSONDecoder().decode(PlaybackPreferences.self, from: data)) ?? .default
    }

    static func save(_ prefs: PlaybackPreferences) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum PlaybackSessionStore {
    private static let key = "lyria.playbackSession"

    static func load() -> PlaybackSession? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PlaybackSession.self, from: data)
    }

    static func save(_ session: PlaybackSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum UISessionStore {
    private static let key = "lyria.uiSession"

    static func load() -> UISession? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UISession.self, from: data)
    }

    static func save(_ session: UISession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

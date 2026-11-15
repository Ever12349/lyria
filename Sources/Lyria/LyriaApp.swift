import AppKit
import SwiftUI
import LyriaCore

@main
struct LyriaApp: App {
    @State private var playback = PlaybackRoot()

    var body: some Scene {
        WindowGroup {
            ContentView(store: playback.session)
                .environment(playback.transport)
                .environment(playback.queue)
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
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            cache.flush()
            MainActor.assumeIsolated {
                session.persistUINow()
            }
        }
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

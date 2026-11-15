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

    init() {
        let prefs = PlaybackPreferenceStore.load()
        let transport = TransportState()
        transport.shuffle = prefs.shuffle
        transport.repeatMode = prefs.repeatMode
        transport.volume = prefs.volume
        let queue = PlaybackQueueState()
        let engine = PlaybackEngine(preferences: prefs, persist: { PlaybackPreferenceStore.save($0) })
        self.transport = transport
        self.queue = queue
        session = AppSession(engine: engine, transport: transport, queueState: queue)
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

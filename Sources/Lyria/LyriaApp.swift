import SwiftUI

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
        let transport = TransportState()
        let queue = PlaybackQueueState()
        let engine = PlaybackEngine()
        self.transport = transport
        self.queue = queue
        session = AppSession(engine: engine, transport: transport, queueState: queue)
    }
}

import SwiftUI

@main
struct LyriaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: LyriaTheme.windowMinimum.width, minHeight: LyriaTheme.windowMinimum.height)
        }
        .defaultSize(width: 1180, height: 760)
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

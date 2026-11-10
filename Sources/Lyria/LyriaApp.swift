import SwiftUI

@main
struct LyriaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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

import AppKit
import SwiftUI

@main
enum LyriaMain {
    static func main() {
        if CommandLine.arguments.contains("--mcp") {
            MCPBridge.run()
        }
        guard InstanceLock.becomePrimary() else { return }
        LyriaApp.main()
    }
}

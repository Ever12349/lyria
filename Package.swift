// swift-tools-version: 5.9
import PackageDescription

// The app target imports SwiftUI. The manifest is evaluated on the host, so Linux
// `swift test` builds LyriaCore + LyriaTests only. Xcode still builds the app.
var products: [Product] = [
    .library(name: "LyriaCore", targets: ["LyriaCore"])
]
var targets: [Target] = [
    .target(
        name: "LyriaCore",
        path: "Sources/LyriaCore"
    ),
    .testTarget(
        name: "LyriaTests",
        dependencies: ["LyriaCore"],
        path: "Tests/LyriaTests"
    )
]

#if os(macOS)
products.append(.executable(name: "Lyria", targets: ["Lyria"]))
targets.append(
    .executableTarget(
        name: "Lyria",
        dependencies: ["LyriaCore"],
        path: "Sources/Lyria"
    )
)
#endif

let package = Package(
    name: "Lyria",
    platforms: [
        .macOS(.v14)
    ],
    products: products,
    targets: targets
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lyria",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Lyria", targets: ["Lyria"])
    ],
    targets: [
        .executableTarget(
            name: "Lyria",
            path: "Sources/Lyria"
        )
    ]
)

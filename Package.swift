// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UptimeKumaNotifier",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift", .upToNextMinor(from: "16.1.1"))
    ],
    targets: [
        .executableTarget(
            name: "UptimeKumaNotifier",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ],
            path: "Sources/UptimeKumaNotifier"
        )
    ]
)

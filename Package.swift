// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KMPObservableBridge",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7),
    ],
    products: [
        .library(
            name: "KMPObservableBridge",
            targets: ["KMPObservableBridge"]
        ),
        .executable(
            name: "kmp-observable-bridge-generator",
            targets: ["KMPObservableBridgeGenerator"]
        ),
    ],
    targets: [
        .target(
            name: "KMPObservableBridge"
        ),
        .executableTarget(
            name: "KMPObservableBridgeGenerator"
        ),
        .testTarget(
            name: "KMPObservableBridgeTests",
            dependencies: ["KMPObservableBridge"]
        ),
    ]
)

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
    dependencies: [
        // Used only by the optional generator executable. The bridge runtime
        // remains dependency-free.
        .package(
            url: "https://github.com/tuist/XcodeProj.git",
            exact: "8.24.0"
        ),
    ],
    targets: [
        .target(
            name: "KMPObservableBridge"
        ),
        .executableTarget(
            name: "KMPObservableBridgeGenerator",
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
            ]
        ),
        .testTarget(
            name: "KMPObservableBridgeTests",
            dependencies: ["KMPObservableBridge"]
        ),
    ]
)

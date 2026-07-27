// swift-tools-version: 5.9

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "KMPObservableBridge",
    platforms: [
        .iOS(.v15),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7),
    ],
    products: [
        .library(
            name: "KMPObservableBridge",
            targets: ["KMPObservableBridge"]
        ),
        .library(
            name: "KMPObservableBridgeSKIE",
            targets: ["KMPObservableBridgeSKIE"]
        ),
        .library(
            name: "KMPObservableBridgeNative",
            targets: ["KMPObservableBridgeNative"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "602.0.0"
        ),
    ],
    targets: [
        .target(
            name: "KMPObservableBridge",
            dependencies: ["KMPObservableBridgeMacros"]
        ),
        .target(
            name: "KMPObservableBridgeSKIE",
            dependencies: ["KMPObservableBridge"]
        ),
        .target(
            name: "KMPObservableBridgeNative",
            dependencies: ["KMPObservableBridge"]
        ),
        .macro(
            name: "KMPObservableBridgeMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "KMPObservableBridgeTests",
            dependencies: ["KMPObservableBridge"]
        ),
        .testTarget(
            name: "KMPObservableBridgeMacroTests",
            dependencies: [
                "KMPObservableBridge",
                "KMPObservableBridgeSKIE",
                "KMPObservableBridgeNative",
                "KMPObservableBridgeMacros",
                .product(
                    name: "SwiftSyntaxMacrosTestSupport",
                    package: "swift-syntax"
                ),
            ],
        ),
    ]
)

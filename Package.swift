// swift-tools-version:5.9
import PackageDescription

// macOS 13 is the deployment target. Linux can still build BeijingTimeCore and
// run tests; the AppKit executable is added only when the manifest runs on macOS.

var products: [Product] = [
    .library(name: "BeijingTimeCore", targets: ["BeijingTimeCore"]),
]

var targets: [Target] = [
    .target(name: "BeijingTimeCore"),
    .testTarget(
        name: "BeijingTimeCoreTests",
        dependencies: ["BeijingTimeCore"]
    ),
]

#if os(macOS)
products.append(.executable(name: "BeijingClock", targets: ["BeijingClock"]))
targets.append(
    .executableTarget(
        name: "BeijingClock",
        dependencies: ["BeijingTimeCore"]
    )
)
#endif

let package = Package(
    name: "BeijingClock",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13)
    ],
    products: products,
    targets: targets
)

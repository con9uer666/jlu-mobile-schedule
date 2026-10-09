// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WatchScheduleCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "WatchScheduleCore", path: ".", exclude: ["WatchScheduleStore.swift", "Tests"], sources: ["WatchSchedule.swift"]),
        .testTarget(name: "WatchScheduleCoreTests", dependencies: ["WatchScheduleCore"], path: "Tests")
    ]
)

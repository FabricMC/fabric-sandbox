// swift-tools-version: 5.9

import PackageDescription

let linkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "/IGNORE:4217"]),
]

let package = Package(
    name: "FabricSandbox",
    products: [
        .library(
            name: "FabricSandbox",
            type: .dynamic,
            targets: ["FabricSandbox"]),
        .library(
            name: "Hook",
            type: .dynamic,
            targets: ["Hook"]),
        .executable(name: "SandboxTest", targets: ["SandboxTest"]),
        .executable(name: "Packager", targets: ["Packager"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-format", revision: "58c2ef5"),
        .package(url: "https://github.com/apple/swift-testing", .upToNextMinor(from: "0.6.0")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/modmuss50/Detours", revision: "23deb11"),
    ],
    targets: [
        .target(
            name: "Jni"
        ),
        // A C library containing additional Windows SDK functions that arent included in the default WinSDK module
        .target(
            name: "WinSDKExtras"
        ),
        // A collection of utility functions for the Windows platform
        .target(
            name: "WindowsUtils",
            dependencies: [ .target(name: "WinSDKExtras") ],
            linkerSettings: linkerSettings
        ),
        // Code shared between the sandbox and the runtime
        .target(
            name: "Shared"
        ),
        // The executable used with the intergration tests
        .executableTarget(
            name: "SandboxTest",
            dependencies: [ .target(name: "WindowsUtils") ],
            linkerSettings: linkerSettings
        ),
        // The generic sandbox library
        .target(
            name: "Sandbox",
            dependencies: [ .target(name: "WinSDKExtras"), .target(name: "WindowsUtils"), .target(name: "Shared")],
            linkerSettings: linkerSettings
        ),
        // The Minecraft/Fabric specific parts of the sandbox
        .target(
            name: "FabricSandbox",
            dependencies: [ .target(name: "Jni"), .target(name: "WinSDKExtras"), .target(name: "WindowsUtils"), .target(name: "Sandbox"), .product(name: "Logging", package: "swift-log")],
            linkerSettings: linkerSettings
        ),
        // The swift code that is used in the sandboxed process, invoked via the hook
        .target(
            name: "Runtime",
            dependencies: [ .target(name: "Shared"), .target(name: "WindowsUtils")],
            // https://github.com/apple/swift-package-manager/issues/7319
            swiftSettings: [.interoperabilityMode(.Cxx), .unsafeFlags(["-emit-clang-header-path", "Sources/Hook/include/Runtime-Swift.h"])]
        ),
        // A DLL using Detours to hook into WIN32 API calls
        .target(
            name: "Hook",
            dependencies: [ .target(name: "Runtime"), .product(name: "Detours", package: "Detours")],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        // Packager to copy all the required files into a single directory
        .executableTarget(
            name: "Packager",
            dependencies: [.target(name: "WinSDKExtras"), .target(name: "WindowsUtils"), .target(name: "Sandbox"), .product(name: "Logging", package: "swift-log")],
            linkerSettings: linkerSettings
        ),
        .testTarget(
            name: "FabricSandboxTests",
            dependencies: [ .target(name: "FabricSandbox"), .target(name: "WindowsUtils"), .product(name: "Testing", package: "swift-testing")],
            linkerSettings: linkerSettings
        ),
    ],
    cxxLanguageStandard: .cxx17
)

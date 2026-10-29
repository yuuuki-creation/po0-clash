// swift-tools-version:5.9
import Foundation
import PackageDescription

// scripts/bundle.sh generates Sources/Po0FFI, Sources/Po0FFIFFI and .ffi/lib/libpo0_ffi.a from crates/ffi.
let root = Context.packageDirectory
let hasBindings = FileManager.default.fileExists(atPath: "\(root)/Sources/Po0FFI/Po0FFI.swift")

var targets: [Target] = [
    .executableTarget(
        name: "Po0Clash",
        dependencies: ["Po0FFI"],
        path: "Sources/Po0Clash"
    ),
]

if hasBindings {
    targets += [
        .systemLibrary(name: "Po0FFIFFI", path: "Sources/Po0FFIFFI"),
        .target(
            name: "Po0FFI",
            dependencies: ["Po0FFIFFI"],
            path: "Sources/Po0FFI",
            linkerSettings: [
                .unsafeFlags(["-L\(root)/.ffi/lib"]),
                .linkedLibrary("po0_ffi"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Security"),
                .linkedFramework("SystemConfiguration"),
            ]
        ),
    ]
} else {
    targets.append(.target(name: "Po0FFI", path: "Sources/Po0FFIMock"))
}

let package = Package(
    name: "Po0Clash",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "po0-clash", targets: ["Po0Clash"])],
    targets: targets,
    swiftLanguageVersions: [.v5]
)

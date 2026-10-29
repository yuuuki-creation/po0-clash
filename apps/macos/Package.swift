// swift-tools-version:5.9
import PackageDescription

// scripts/bundle.sh generates Sources/Po0FFI, Sources/Po0FFIFFI and .ffi/lib/libpo0_ffi.a from crates/ffi.
let root = Context.packageDirectory

let package = Package(
    name: "Po0Clash",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "po0-clash", targets: ["Po0Clash"])],
    targets: [
        .executableTarget(
            name: "Po0Clash",
            dependencies: ["Po0FFI"],
            path: "Sources/Po0Clash"
        ),
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
    ],
    swiftLanguageVersions: [.v5]
)

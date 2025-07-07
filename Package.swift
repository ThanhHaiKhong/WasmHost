// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if FFI_DEBUG
let ffiTargets: [PackageDescription.Target] = [
    .binaryTarget(name: "mffi", path: "../../../be/apps/rsmobile/target/ios/mffi_dev.zip"),
]
#else
let mffi_file_name = "mffi_music_tube_3ba54735ff20.xcframework.zip"
let mffi_checksum = "3ba54735ff20c928fbf0fdb3a71076410b3a0499ef5e6c89f1dd3ddf6450c15b"

let ffiTargets: [PackageDescription.Target] = [
    .binaryTarget(name: "mffi", url: "https://scwasm.sfo3.cdn.digitaloceanspaces.com/\(mffi_file_name)", checksum: mffi_checksum),
]
#endif

let package = Package(
    name: "WasmHost",
    platforms: [
        .macOS(.v11), .iOS(.v15), .watchOS(.v8),
    ],
    products: [
		.singleTargetLibrary("AsyncWasm"),
		.singleTargetLibrary("MusicWasm"),
		.singleTargetLibrary("TaskWasm"),
		.singleTargetLibrary("WasmSwiftProtobuf"),
		.singleTargetLibrary("WasmObjCProtobuf"),
		.singleTargetLibrary("MobileFFI"),
		.singleTargetLibrary("AsyncWasmUI", type: .dynamic)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system", .upToNextMinor(from: "1.3.0")),
        .package(url: "https://github.com/swiftwasm/WasmKit.git", from: "0.1.5"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.22.0"),
        .package(url: "https://github.com/hyperoslo/Cache.git", from: "7.4.0")
    ],
    targets: ffiTargets + [
        .target(
            name: "AsyncWasmKit",
            dependencies: [
                .product(name: "WasmKit", package: "WasmKit"),
                .product(name: "SystemPackage", package: "swift-system"),
                "WasmSwiftProtobuf",
            ],
            resources: [
                .copy("Resources/base.wasm"),
            ]
        ),
        .target(
            name: "WasmSwiftProtobuf",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ]
        ),
        .target(
            name: "AsyncWasm",
            dependencies: [
                "WasmSwiftProtobuf",
                .target(name: "MobileFFI", condition: .when(platforms: [.iOS, .macOS])),
                .target(name: "AsyncWasmKit", condition: .when(platforms: [.watchOS]))
            ]
        ),
        .target(
            name: "MusicWasm",
            dependencies: [
                "TaskWasm"
            ]
        ),
        .target(
            name: "TaskWasm",
            dependencies: [
                "AsyncWasm",
                "Cache"
            ]
        ),
        .target(
            name: "AsyncWasmUI",
            dependencies: [
                "AsyncWasm"
            ]
        ),
        .target(
            name: "Protobuf",
            dependencies: [
                
            ],
            exclude: [
                "GPBUnknownField+Additions.swift",
                "GPBUnknownFields+Additions.swift",
                "GPBProtocolBuffers.m"
            ],
            publicHeadersPath: "",
            cSettings: [
                .unsafeFlags(["-fno-objc-arc"])
            ]
        ),
        .target(
            name: "AsyncWasmObjC",
            dependencies: [
                "Protobuf",
                "AsyncWasm",
            ],
            publicHeadersPath: "include"
        ),
        .target(
            name: "WasmObjCProtobuf",
            dependencies: [
                "Protobuf",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-fno-objc-arc"])
            ]
        ),
        .target(
            name: "MobileFFI",
            dependencies: [
                .target(name: "mffi", condition: .when(platforms: [.iOS, .macOS])),
            ]
        ),
        .testTarget(
            name: "AsyncWasmTests",
            dependencies: [
                "AsyncWasm"
            ],
            resources: [
                .copy("Resources/music_tube.wasm"),
            ]
        ),
        .testTarget(
            name: "MusicWasmTests",
            dependencies: [
                "MusicWasm"
            ],
            resources: [
                .copy("Resources/music_tube.wasm"),
            ]
        ),
        .testTarget(
            name: "MusicWasmObjCTests",
            dependencies: [
                "WasmObjCProtobuf",
                "AsyncWasmObjC",
                "MusicWasm"
            ],
            resources: [
                .copy("Resources/music_tube.wasm"),
            ]
        )
    ]
)

extension Product {
    static func singleTargetLibrary(_ name: String, type: PackageDescription.Product.Library.LibraryType? = nil) -> Product {
		return .library(name: name, type: type, targets: [name])
    }
}

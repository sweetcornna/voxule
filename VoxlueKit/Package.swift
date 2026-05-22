// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VoxlueKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "VoxlueData", targets: ["VoxlueData"]),
        .library(name: "VoxlueServices", targets: ["VoxlueServices"]),
        .library(name: "VoxlueDesign", targets: ["VoxlueDesign"]),
    ],
    targets: [
        .target(name: "VoxlueData"),
        .testTarget(name: "VoxlueDataTests", dependencies: ["VoxlueData"]),
        // VoxlueServices 领域服务层，依赖 VoxlueData（路线图 §3.0）。
        .target(name: "VoxlueServices", dependencies: ["VoxlueData"]),
        .testTarget(name: "VoxlueServicesTests", dependencies: ["VoxlueServices"]),
        // VoxlueDesign 独立、不依赖 VoxlueData/VoxlueServices（路线图 §3.0）。
        .target(
            name: "VoxlueDesign",
            resources: [
                // 字体文件随包打成 resource bundle，首次使用时经 CoreText 注册。
                .copy("Fonts/Resources"),
            ]
        ),
        .testTarget(name: "VoxlueDesignTests", dependencies: ["VoxlueDesign"]),
    ]
)

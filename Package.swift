// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "OBDIQIosSdk",
    platforms: [
        .iOS(.v12),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "OBDIQIosSdk",
            targets: ["OBDIQIosSdk"]
        ),
    ],
    dependencies: [
        .package(
            url: "git@github.com:RRCummins/RepairClubSDK.git",
            from: "1.3.2-beta.1"
        ),
        .package(
            url: "https://github.com/SwiftyJSON/SwiftyJSON.git",
            from: "5.0.2"
        ),
    ],
    targets: [
        .target(
            name: "OBDIQIosSdk",
            dependencies: [
                .product(name: "RepairClubSDK", package: "RepairClubSDK"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON")
            ]
        )
    ]
)


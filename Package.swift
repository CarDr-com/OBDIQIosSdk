// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "OBDIQIosSdk",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "OBDIQIosSdk",
            targets: ["OBDIQIosSdk"]
        ),
    ],
    dependencies: [
        .package(
            url: "git@github.com:repairclub/repairclub-ios-sdk.git",
            from: "1.5.5-beta.8"
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
                .product(name: "RepairClubSDK", package: "repairclub-ios-sdk"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON")
            ]
        )
    ]
)


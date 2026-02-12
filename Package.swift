// swift-tools-version: 6.2
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
        // Binary SDK package
        .package(
            url: "https://github.com/repairclub/repairclub-ios-sdk.git",
            from: "1.5.6"
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
        ),
    ]
)

// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "gis-tools-csv",
    platforms: [
        .iOS(.v15),
        .macOS(.v15),
        .tvOS(.v15),
        .watchOS(.v7),
    ],
    products: [
        .library(
            name: "GISToolsCSV",
            targets: ["GISToolsCSV"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Outdooractive/gis-tools.git", from: "2.3.0"),
    ],
    targets: [
        .target(
            name: "GISToolsCSV",
            dependencies: [
                .product(name: "GISTools", package: "gis-tools"),
            ]),
        .testTarget(
            name: "GISToolsCSVTests",
            dependencies: ["GISToolsCSV"],
            resources: [.copy("TestData")]),
    ]
)

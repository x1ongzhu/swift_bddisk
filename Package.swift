// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BaiduNetDisk",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "BaiduNetDisk", targets: ["BaiduNetDisk"])],
    targets: [
        .target(name: "NetDiskCore"),
        .executableTarget(name: "BaiduNetDisk", dependencies: ["NetDiskCore"]),
        .testTarget(name: "NetDiskCoreTests", dependencies: ["NetDiskCore"])
    ]
)

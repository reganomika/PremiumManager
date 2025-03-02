// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "PremiumManager",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PremiumManager",
            targets: ["PremiumManager"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apphud/ApphudSDK.git", from: "3.5.9"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.5.0")
    ],
    targets: [
        .target(
            name: "PremiumManager",
            dependencies: [
                .product(name: "ApphudSDK", package: "ApphudSDK"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxCocoa", package: "RxSwift")
            ],
            path: "Sources/PremiumManager"),
        .testTarget(
            name: "PremiumManagerTests",
            dependencies: ["PremiumManager"],
            path: "Tests/PremiumManagerTests"),
    ]
)

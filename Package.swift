// swift-tools-version:5.3

import PackageDescription

let package = Package(
	name: "Megrez",
	products: [
		.library(
			name: "Megrez",
			targets: ["Megrez"]
		)
	],
	dependencies: [
		.package(url: "https://gitee.com/mirrors_apple/swift-collections", from: "1.0.2")
	],
	targets: [
		.target(
			name: "Megrez",
			dependencies: [
				.product(name: "OrderedCollections", package: "swift-collections")
			]
		),
		.testTarget(
			name: "MegrezTests",
			dependencies: ["Megrez"]
		),
	]
)

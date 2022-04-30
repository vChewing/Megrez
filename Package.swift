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
	dependencies: [],
	targets: [
		.target(
			name: "Megrez",
			dependencies: []
		),
		.testTarget(
			name: "MegrezTests",
			dependencies: ["Megrez"]
		),
	]
)

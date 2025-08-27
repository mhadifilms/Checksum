// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Checksum",
	platforms: [
		.macOS(.v13)
	],
	products: [
		.library(name: "ChecksumKit", targets: ["ChecksumKit"]),
		.executable(name: "checksum", targets: ["checksum"]),
		.executable(name: "Checksum", targets: ["ChecksumApp"]) // SwiftUI app (P2)
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
	],
	targets: [
		.target(
			name: "ChecksumKit",
			dependencies: []
		),
		.executableTarget(
			name: "checksum",
			dependencies: [
				"ChecksumKit",
				.product(name: "ArgumentParser", package: "swift-argument-parser")
			]
		),
		.executableTarget(
			name: "ChecksumApp",
			dependencies: ["ChecksumKit"],
			path: "Sources/ChecksumApp",
			resources: []
		),
		.testTarget(
			name: "ChecksumKitTests",
			dependencies: ["ChecksumKit"]
		)
	]
)

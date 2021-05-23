// swift-tools-version:5.3
import PackageDescription

let package = Package(
	name: "Players",
	platforms: [
		.macOS(.v10_15)
	],
	products: [
//		.library(name: "Players", type: .static, targets: ["HTMLPlayer"])
	],
	targets: [
		.target(name: "HTMLPlayer", path: "HTML",
			exclude: ["Makefile", "hls.d.ts"],
			resources: [.copy("player.html"), .copy("player.js")]
		)
	]
)

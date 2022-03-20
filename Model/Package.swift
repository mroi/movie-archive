// swift-tools-version:5.6
import PackageDescription

let package = Package(
	name: "Model",
	platforms: [
		.macOS(.v12)
	],
	products: [
		.library(name: "MovieArchiveModel", targets: ["MovieArchiveModel"])
	],
	targets: [
		.target(name: "MovieArchiveModel", path: ".")
	]
)

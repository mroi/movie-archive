// swift-tools-version:5.7
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

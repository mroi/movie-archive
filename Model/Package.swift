// swift-tools-version:6.3
import PackageDescription

let package = Package(
	name: "Model",
	defaultLocalization: "en",
	platforms: [
		.macOS(.v26)
	],
	products: [
		.library(name: "MovieArchiveModel", targets: ["MovieArchiveModel"])
	],
	targets: [
		.target(name: "MovieArchiveModel", path: ".")
	]
)

// swift-tools-version:5.6
import PackageDescription

let package = Package(
	name: "Converter",
	platforms: [
		.macOS(.v12)
	],
	products: [
		.library(name: "MovieArchiveConverter", targets: ["MovieArchiveConverter"])
	],
	targets: [
		.target(name: "MovieArchiveConverter", path: ".")
	]
)

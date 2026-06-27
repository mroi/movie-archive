// swift-tools-version:5.7
import PackageDescription

let package = Package(
	name: "Converter",
	defaultLocalization: "en",
	platforms: [
		.macOS(.v13)
	],
	products: [
		.library(name: "MovieArchiveConverter", targets: ["MovieArchiveConverter"])
	],
	targets: [
		.target(name: "MovieArchiveConverter", path: ".")
	]
)

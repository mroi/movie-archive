// swift-tools-version:6.3
import PackageDescription

let package = Package(
	name: "Converter",
	defaultLocalization: "en",
	platforms: [
		.macOS(.v26)
	],
	products: [
		.library(name: "MovieArchiveConverter", targets: ["MovieArchiveConverter"])
	],
	targets: [
		.target(name: "MovieArchiveConverter", path: ".")
	]
)

// swift-tools-version:5.7
import PackageDescription

let package = Package(
	name: "Importers",
	platforms: [
		.macOS(.v12)
	],
	products: [
		.library(name: "MovieArchiveImporters", targets: ["MovieArchiveImporters"])
	],
	dependencies: [
		.package(name: "Model", path: "../Model"),
		.package(name: "Converter", path: "../XPCConverter/Converter")
	],
	targets: [
		.target(name: "MovieArchiveImporters", dependencies: [
			.product(name: "MovieArchiveModel", package: "Model"),
			.product(name: "MovieArchiveConverter", package: "Converter")
		], path: ".")
	]
)

// swift-tools-version:5.7
import PackageDescription

let package = Package(
	name: "Exporters",
	defaultLocalization: "en",
	platforms: [
		.macOS(.v12)
	],
	products: [
		.library(name: "MovieArchiveExporters", targets: ["MovieArchiveExporters"]),
	],
	dependencies: [
		.package(name: "Model", path: "../Model"),
		.package(name: "Converter", path: "../XPCConverter/Converter")
	],
	targets: [
		.target(name: "MovieArchiveExporters", dependencies: [
			.product(name: "MovieArchiveModel", package: "Model"),
			.product(name: "MovieArchiveConverter", package: "Converter")
		], path: ".")
	]
)

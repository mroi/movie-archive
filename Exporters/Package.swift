// swift-tools-version:5.5
import PackageDescription

let package = Package(
	name: "Exporters",
	platforms: [
		.macOS(.v11)
	],
	products: [
		.library(name: "MovieArchiveExporters", targets: ["MovieArchiveExporters"]),
	],
	dependencies: [
		.package(name: "Model", path: "../Model")
	],
	targets: [
		.target(name: "MovieArchiveExporters", dependencies: [
			.product(name: "MovieArchiveModel", package: "Model")
		], path: ".")
	]
)

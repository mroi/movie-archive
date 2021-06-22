// swift-tools-version:5.5
import PackageDescription

let package = Package(
	name: "Importers",
	platforms: [
		.macOS(.v11)
	],
	products: [
		.library(name: "MovieArchiveImporters", targets: ["MovieArchiveImporters"])
	],
	dependencies: [
		.package(name: "Model", path: "../Model")
	],
	targets: [
		.target(name: "MovieArchiveImporters", dependencies: [
			.product(name: "MovieArchiveModel", package: "Model")
		], path: ".")
	]
)

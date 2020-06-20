// swift-tools-version:5.2
import PackageDescription

let package = Package(
	name: "Importers",
	platforms: [
		.macOS(.v10_15)
	],
	products: [
		.library(name: "Importers", type: .static, targets: ["MovieArchiveImporters"]),
	],
	targets: [
		.target(name: "MovieArchiveImporters", path: ".")
	]
)

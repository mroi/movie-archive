// swift-tools-version:5.3
import PackageDescription

let package = Package(
	name: "Importers",
	platforms: [
		.macOS(.v10_16)
	],
	products: [
		.library(name: "Importers", type: .static, targets: ["MovieArchiveImporters"]),
	],
	targets: [
		.target(name: "MovieArchiveImporters", path: ".")
	]
)

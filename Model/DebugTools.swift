import Foundation


#if DEBUG

/// Test importer which throws on `generate()`.
struct ThrowingImporter: ImportPass {
	init(source: URL = URL(fileURLWithPath: ".")) {}
	func generate() throws -> MediaTree {
		struct EmptyError: Error {}
		throw EmptyError()
	}
}

/// Test exporter which black-holes its input.
struct NullExporter: ExportPass {
	func consume(_ mediaTree: MediaTree) {}
}

#endif

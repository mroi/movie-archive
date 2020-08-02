import SwiftUI
import UniformTypeIdentifiers
import MovieArchiveImporters


/// Represents importing content from an external source like a DVD into the archive.
///
/// This document is called ‘import’ because this is what the user experiences in the context of the macOS app.
/// However, internally it uses an importer and an exporter. The importer reads from the external source into
/// the internal data model. The exporter outputs from the data model to the movie archive storage format.
struct ImportDocument: FileDocument {

	static var readableContentTypes: [UTType] = [ .import ]

	init() {}
	init(configuration: ReadConfiguration) throws {}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		return FileWrapper(regularFileWithContents: Data())
	}
}

extension UTType {
	static var `import`: UTType {
		UTType(importedAs: "de.reactorcontrol.movie-archive.import")
	}
}

struct ImportDocumentView: View {
	@Binding var document: ImportDocument
	var body: some View {
		TestView()
	}
}

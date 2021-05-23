import SwiftUI
import UniformTypeIdentifiers
import MovieArchiveImporters


/// Represents ingesting content from an external source like a DVD into the archive.
///
/// In the user experience, this process is typically called ‘import’.
/// However, it is internally implemented as a combination of an importer and an exporter.
/// The importer reads from the external source into internal data model.
/// The exporter outputs from the data model to the movie archive storage format.
struct IngestDocument: FileDocument {

	static var readableContentTypes: [UTType] = [ .ingestDocument ]

	init() {}
	init(configuration: ReadConfiguration) throws {}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		return FileWrapper(regularFileWithContents: Data())
	}
}

extension UTType {
	static let ingestDocument = UTType(exportedAs: "de.reactorcontrol.movie-archive.ingest")
}

struct IngestDocumentView: View {
	@Binding var document: IngestDocument
	var body: some View {
		TestView()
	}
}

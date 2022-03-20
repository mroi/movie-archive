import MovieArchiveModel


/// Serialize a `MediaTree` to an external data format.
///
/// `Exporter` is the public interface of all export functionality. The exporter
/// consumes a `MediaTree` and generates a specified external data format from
/// it. It internally combines a number of passes to achieve its result.
///
/// - Remark: Exporters form a use case layer on top of the model types.
public struct Exporter: ExportPass {

	private let selectedExporter: any ExportPass

	/// Data formats for which an `Exporter` is available.
	public enum Format {

		/// Movie Archive’s canonical library storage format.
		///
		/// The `MediaTree` is serialized to JSON and assets are encoded with
		/// modern codecs. Interactive menus are playable by HTML or native
		/// clients.
		case movieArchiveLibrary
	}

	/// Instantiates an exporter for the given output format.
	public init(format: Format) {
		switch format {
		case .movieArchiveLibrary:
			selectedExporter = LibraryExporter()
		}
	}

	public func consume(_ mediaTree: MediaTree) async throws {
		try await selectedExporter.consume(mediaTree)
	}

	public var description: String { String(describing: selectedExporter) }
}

import Foundation
import MovieArchiveModel


/// Generate a `MediaTree` by importing from an external data source.
///
/// `Importer` is the public interface of all import functionality. When
/// initialized with a URL to external source data, it will automatically detect
/// the format and select a supported internal importer. The importer works by
/// combining a number of passes to generate a final `MediaTree` from the
/// external data source.
///
/// - Remark: Importers form a use case layer on top of the model types.
public struct Importer: ImportPass {

	private let availableImporters = [ DVDImporter.self ]
	private let selectedImporter: ImportPass

	/// Failure cases for importer initialization.
	public enum Error: Swift.Error {
		case SourceNotSupported
	}

	/// Instantiates the first available importer supporting the source.
	public init(source url: URL) throws {
		for importerType in availableImporters {
			do {
				let importer = try importerType.init(source: url)
				selectedImporter = importer
				return
			} catch {
				continue
			}
		}
		throw Error.SourceNotSupported
	}
}

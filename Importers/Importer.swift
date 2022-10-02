import Foundation
import MovieArchiveModel

import enum MovieArchiveConverter.ConverterError


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
	private let selectedImporter: any ImportPass

	/// Failure cases for importer initialization.
	public typealias Error = ConverterError

	/// Instantiates the first available importer supporting the source.
	public init(source url: URL) async throws {
		for importerType in availableImporters {
			do {
				selectedImporter = try await importerType.init(source: url)
				return
			} catch Error.sourceNotSupported {
				continue
			}
		}
		throw Error.sourceNotSupported
	}

	public func generate() async throws -> MediaTree {
		return try await selectedImporter.generate()
	}

	public var description: String { String(describing: selectedImporter) }
}

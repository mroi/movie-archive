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

	/// Autodetects the source and creates an appropriate importer.
	public init(source: URL) throws {}
}

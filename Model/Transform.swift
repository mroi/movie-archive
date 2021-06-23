/// An end-to-end `MediaTree` transformation, combining one importer and one exporter `Pass`.
///
/// The `Transform` executes exactly two passes on an initially empty `MediaTree`:
/// An importer generates a media tree representation from an imported source.
/// An exporter serializes the media tree to a persistent format.
///
/// - Remark: Typical clients use a `Transform` together with an appropriate
///   importer and exporter as the entry point into model functionality.
public class Transform {

	let importer: ImportPass
	let exporter: ExportPass

	/// Creates an instance combining the provided importer and exporter.
	public init(importer: ImportPass, exporter: ExportPass) {
		self.importer = importer
		self.exporter = exporter
	}
}

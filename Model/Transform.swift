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

	/// Execute the transform.
	///
	/// This function is asynchronous, so any long-running work will yield to
	/// the caller. For status updates and interacting with the transform like
	/// configuring options, you must subscribe to the `publisher` property.
	public func execute() {  // TODO: convert to async function
		// TODO: set up publisher
		do {
			let mediaTree = try importer.generate()
			try exporter.consume(mediaTree)
		} catch {
			// TODO: post error to publisher
		}
	}
}

extension Transform: CustomStringConvertible {
	public var description: String { "\(importer) → \(exporter)" }
}

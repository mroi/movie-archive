import Foundation
import Combine
import MovieArchiveModel
import MovieArchiveConverter


struct DVDImporter: ImportPass {

	private let dvdReader: DVDReader

	init(source url: URL) async throws {
		dvdReader = try await DVDReader(source: url)
	}

	func generate() async throws -> MediaTree {
		let subscription = dvdReader.publisher
			.map { Transform.Status($0) }
			.mapError { $0 }
			.subscribe(Transform.subject)
		defer { subscription.cancel() }

		let info = try await dvdReader.info()

		let node = MediaTree.OpaqueNode(payload: info)
		return .opaque(node)
	}
}


private extension Transform.Status {

	/// Translate from `ConverterConnection` to `Transform` publisher output.
	///
	/// This initializer bridges an impedance mismatch in publisher values.
	/// The `DVDImporter` uses the XPC converter as an internal implementation
	/// detail. This converter uses a publisher for asynchronous messaging.
	/// To forward its output to the `Transform` publisher, we need to translate
	/// the values. We do not want to expose implementation details like the
	/// XPC converter on the `Transform` API surface.
	init(_ input: ConverterOutput) {
		switch input {
		case .message(let level, let text):
			self = .message(level: level, text)
		case .progress(let progress):
			self = .progress(progress)
		}
	}
}

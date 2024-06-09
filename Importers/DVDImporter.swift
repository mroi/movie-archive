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
		let subscription = await dvdReader.publisher
			.map { Transform.Status($0) }
			.mapError { $0 }
			.subscribe(Transform.subject)
		defer { subscription.cancel() }

		let info = try await dvdReader.info()
		let tree = MediaTree.opaque(.init(payload: info))

#if DEBUG
		// record DVD source data and resulting media tree for use in testing
		let wrapper = Base.Record(toPath: "DVD", identifier: info.discId) {
			return subPasses
		}
		return try await wrapper.process(tree)
#else
		return try await process(bySubPasses: tree)
#endif
	}
}

extension DVDImporter: SubPassRecursing {

	@SubPassBuilder
	var subPasses: [any Pass] {
		// TODO: gradually amend with passes until manual editing can be removed
		Base.MediaTreeInteraction()
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

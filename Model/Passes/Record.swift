import Foundation


extension Base {

	/// A pass which stores its input and output media trees on disk.
	///
	/// The media trees are stored before and after processing by sub-passes.
	///
	/// Storage is in compressed JSON files within the hardcoded app sandbox
	/// container directory. This is also appropriate for tests and playgrounds,
	/// because these are not sandboxed.
	///
	/// A subdirectory within the documents folder is given as an initializer
	/// argument, as well as an identifier for the pair of media trees. A
	/// hexadecimal representation of this identifier, amended with `input` and
	/// `output` is used for the file names.
	public struct Record<Identifier: DataProtocol & Sendable>: Pass, SubPassRecursing {
		public let subPasses: [any Pass]
		let pathComponent: String
		let identifier: Identifier
		
		public init(toPath pathComponent: String, identifier: Identifier,
		            @SubPassBuilder _ builder: () -> [any Pass]) {
			self.pathComponent = pathComponent
			self.identifier = identifier
			subPasses = builder()
		}

		public func process(_ mediaTree: MediaTree) async throws -> MediaTree {
			let home = FileManager.default.homeDirectoryForCurrentUser
#if os(macOS)
			// store JSON in the documents directory within a hardcoded container
			let documents = URL(fileURLWithPath: "Library/Containers/de.reactorcontrol.movie-archive.macos/Data/Documents", relativeTo: home)
#else
#error("unsupported platform")
#endif
			let store = documents.appendingPathComponent(pathComponent)
			try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)

			let baseName = identifier.map({ String(format: "%02x", $0) }).joined()

			try await mediaTree.json().write(to: store.appendingPathComponent(baseName + "-input"))
			let mediaTree = try await process(bySubPasses: mediaTree)
			try await mediaTree.json().write(to: store.appendingPathComponent(baseName + "-output"))

			return mediaTree
		}
	}
}

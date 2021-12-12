import Foundation
import MovieArchiveModel
import MovieArchiveConverter


struct DVDImporter: ImportPass {

	private let dvdReader: DVDReader

	init(source url: URL) throws {
		dvdReader = try DVDReader(source: url)
	}

	func generate() throws -> MediaTree {
		// TODO: connect DVDReader publisher to transform subject

		let info = try dvdReader.info()

		let node = MediaTree.OpaqueNode(children: [], payload: info)
		return .opaque(node)
	}
}

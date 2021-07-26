import Foundation
import MovieArchiveModel
import MovieArchiveConverter


struct DVDImporter: ImportPass {

	init(source url: URL) throws {
		let _ = try DVDReader(source: url)
	}

	func generate() throws -> MediaTree {
		// FIXME: read DVD IFO data
		return .opaque
	}
}

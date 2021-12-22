import Foundation
import os


#if DEBUG

/// Test importer which throws on `generate()`.
struct ThrowingImporter: ImportPass {
	init(source: URL = URL(fileURLWithPath: ".")) {}
	func generate() throws -> MediaTree {
		struct EmptyError: Error {}
		throw EmptyError()
	}
}

/// Test exporter which black-holes its input.
struct NullExporter: ExportPass {
	func consume(_ mediaTree: MediaTree) {}
}

extension OSLogType: CustomStringConvertible {
	public var description: String {
		switch self {
		case .debug: return "debug"
		case .info: return "info"
		case .default: return "notice"
		case .error: return "error"
		case .fault: return "fault"
		default: return "unknown"
		}
	}
}

#endif

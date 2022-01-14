import Foundation
import os


#if DEBUG

/// Test importer processing a given media tree with sub-passes.
struct TestImporter: ImportPass, SubPassRecursing {
	let mediaTree: MediaTree
	let subPasses: [Pass]
	init(_ mediaTree: MediaTree, @SubPassBuilder _ builder: () -> [Pass] = {[]}) {
		self.mediaTree = mediaTree
		self.subPasses = builder()
	}
	init(source: URL = URL(fileURLWithPath: ".")) {
		self.init(.collection(.init(children: [])))
	}
	func generate() async throws -> MediaTree {
		return try await process(bySubPasses: mediaTree)
	}
}

/// Test importer which throws on `generate()`.
struct ThrowingImporter: ImportPass {
	init(source: URL = URL(fileURLWithPath: ".")) {}
	func generate() throws -> MediaTree {
		struct EmptyError: Error {}
		throw EmptyError()
	}
}

/// A namespace for test passes.
enum Test {

	/// Test pass outputting its input.
	struct Identity: Pass {
		func process(_ mediaTree: MediaTree) -> MediaTree { mediaTree }
	}

	/// Test pass signalling a true condition until a countdown reaches zero.
	struct Countdown: Pass, ConditionFlag {
		var remaining: Int
		var condition: Bool { remaining > 0 }
		init(_ count: Int) { remaining = count }
		mutating func process(_ mediaTree: MediaTree) -> MediaTree {
			remaining -= 1
			return mediaTree
		}
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

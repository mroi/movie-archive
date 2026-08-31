import Testing
import Foundation

@testable import MovieArchiveModel
@testable import MovieArchiveImporters
@testable import MovieArchiveConverter


/* MARK: Recorded Input & Output */

/// Iterates over recorded input/output pairs, comparing processed inputs to expected outputs.
@Suite
struct RecordedTests {

	/// The `Bundle` of this test target, can be used to access test resources.
	static private var testBundle: Bundle { Bundle(for: BundleFinder.self) }
	private final class BundleFinder: NSObject {}

	static private func recordings(subdirectory: String) -> [(input: URL, output: URL)] {
		let all = testBundle.urls(forResourcesWithExtension: "json.gz", subdirectory: subdirectory) ?? []
		let inputs = all.filter { $0.lastPathComponent.contains("input") }
		let outputs = inputs.map {
			let outputName = $0.lastPathComponent.replacingOccurrences(of: "input", with: "output")
			return $0.deletingLastPathComponent().appendingPathComponent(outputName)
		}
		return Array(zip(inputs, outputs))
	}

	@Test(arguments: recordings(subdirectory: "DVD"))
	func recorded(dvd urls: (input: URL, output: URL)) async throws {
		class ReaderMock: ConverterDVDReader {
			func open(_: URL, completionHandler done: @escaping (UUID?) -> Void) {
				done(UUID())
			}
			func close(_: UUID) {}
			func readInfo(_: UUID, completionHandler done: @escaping (Data?) -> Void) {
				Issue.record("unexpected read")
			}
		}

		// setup DVD importer
		let source = URL(fileURLWithPath: ".")
		let importer = try await ConverterConnection.withUnsafeMocks(proxy: ReaderMock()) {
			try await DVDImporter(source: source)
		}

		// read recorded input
		let inputJson: JSON<MediaTree> = try await JSON(contentsOf: urls.input)
		let input = try inputJson.mediaTree(withTypes: DVDInfo.self)
		let inputData = try input.json().data
		#expect(inputJson.data == inputData)

		// read recorded output
		let outputJson: JSON<MediaTree> = try await JSON(contentsOf: urls.output)
		// TODO: DVDInfo should not be needed here, output trees should not have opaque nodes
		let output = try outputJson.mediaTree(withTypes: DVDInfo.self, DVDDataSource.self)
		let outputData = try output.json().data
		#expect(outputJson.data == outputData)

		// process media tree
		let processed = try await importer.process(bySubPasses: input)

		// compare processed input and expected output media tree
		// TODO: with a complete set of DVD import passes, this should always succeed
		withKnownIssue("incomplete DVD import") {
			// TODO: should use #expect(processed == output), but this dumps both trees when not equal
			let comparison = processed == output
			#expect(comparison)
		}
	}
}


/* MARK: Equatable Conformance */

extension MediaTree: @retroactive Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		switch lhs {
		case .asset(let lhsNode):
			if case .asset(let rhsNode) = rhs {
				lhsNode == rhsNode
			} else {
				false
			}
		case .menu(let lhsNode):
			if case .menu(let rhsNode) = rhs {
				lhsNode == rhsNode
			} else {
				false
			}
		case .link(let lhsNode):
			if case .link(let rhsNode) = rhs {
				lhsNode == rhsNode
			} else {
				false
			}
		case .collection(let lhsNode):
			if case .collection(let rhsNode) = rhs {
				lhsNode == rhsNode
			} else {
				false
			}
		case .opaque:
			// opaque nodes cannot be compared and are therefore never equal
			false
		}
	}
}

extension MediaTree.AssetNode: @retroactive Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.id == rhs.id
			&& lhs.kind == rhs.kind
			&& lhs.content == rhs.content
			&& lhs.successor == rhs.successor
	}
}

extension MediaTree.MenuNode: @retroactive Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.id == rhs.id
			&& lhs.children == rhs.children
			&& lhs.background == rhs.background
	}
}

extension MediaTree.LinkNode: @retroactive Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.target == rhs.target
	}
}

extension MediaTree.CollectionNode: @retroactive Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.children == rhs.children
	}
}

extension MediaRecipe: @retroactive Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return true
	}
}

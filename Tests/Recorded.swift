import XCTest

@testable import MovieArchiveModel
@testable import MovieArchiveImporters
@testable import MovieArchiveConverter


/* MARK: Recorded Input & Output */

/// Iterates over recorded input/output pairs, comparing processed inputs to expected outputs.
class RecordedTests: XCTestCase {

	/// The `Bundle` of this test class, can be used to access test resources.
	private var testBundle: Bundle { Bundle(for: type(of: self)) }

	func testRecordedDVDs() async {
		class ReaderMock: ConverterDVDReader {
			func open(_: URL, completionHandler done: @escaping (UUID?) -> Void) {
				done(UUID())
			}
			func close(_: UUID) {}
			func readInfo(_: UUID, completionHandler done: @escaping (Data?) -> Void) {
				XCTFail("unexpected read")
			}
		}

		// setup DVD importer
		let source = URL(fileURLWithPath: ".")
		let importer = await ConverterConnection.withMocks(proxy: ReaderMock()) {
			try! await DVDImporter(source: source)
		}

		// iterate over all recorded DVDs
		let urls = testBundle.urls(forResourcesWithExtension: "json.gz", subdirectory: "DVD")
		guard let urls else { return }

		for inputUrl in urls where inputUrl.lastPathComponent.contains("input") {

			// read recorded input
			var inputJson: JSON<MediaTree>!
			var input: MediaTree!
			await XCTAssertNoThrowAsync(inputJson = try await JSON(contentsOf: inputUrl))
			XCTAssertNoThrow(input = try inputJson.mediaTree(withTypes: [DVDInfo.self]))
			XCTAssertEqual(inputJson.data, try! input.json().data)

			// read recorded output
			let outputName = inputUrl
				.lastPathComponent
				.replacingOccurrences(of: "input", with: "output")
			let outputUrl = inputUrl
				.deletingLastPathComponent()
				.appendingPathComponent(outputName)
			var outputJson: JSON<MediaTree>!
			var output: MediaTree!
			await XCTAssertNoThrowAsync(outputJson = try await JSON(contentsOf: outputUrl))
			// TODO: DVDInfo should not be needed here, output trees should not have opaque nodes
			XCTAssertNoThrow(output = try outputJson.mediaTree(withTypes: [DVDInfo.self, DVDDataSource.self]))
			XCTAssertEqual(outputJson.data, try! output.json().data)

			// process media tree
			let processed = try! await importer.process(bySubPasses: input)

			// compare processed input and expected output media tree
			// TODO: with a complete set of DVD import passes, this should always succeed
			XCTExpectFailure("incomplete DVD import")
			// TODO: should use XCTAssertEqual, but this dumps both trees when not equal
			XCTAssertTrue(processed == output)
		}
	}
}


/* MARK: Equatable Conformance */

extension MediaTree: Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		switch lhs {
		case .asset(let lhsNode):
			if case .asset(let rhsNode) = rhs {
				return lhsNode == rhsNode
			} else {
				return false
			}
		case .menu(let lhsNode):
			if case .menu(let rhsNode) = rhs {
				return lhsNode == rhsNode
			} else {
				return false
			}
		case .link(let lhsNode):
			if case .link(let rhsNode) = rhs {
				return lhsNode == rhsNode
			} else {
				return false
			}
		case .collection(let lhsNode):
			if case .collection(let rhsNode) = rhs {
				return lhsNode == rhsNode
			} else {
				return false
			}
		case .opaque:
			// opaque nodes cannot be compared and are therefore never equal
			return false
		}
	}
}

extension MediaTree.AssetNode: Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.id == rhs.id
			&& lhs.kind == rhs.kind
			&& lhs.content == rhs.content
			&& lhs.successor == rhs.successor
	}
}

extension MediaTree.MenuNode: Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.id == rhs.id
			&& lhs.children == rhs.children
			&& lhs.background == rhs.background
	}
}

extension MediaTree.LinkNode: Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.target == rhs.target
	}
}

extension MediaTree.CollectionNode: Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.children == rhs.children
	}
}

extension MediaRecipe: Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return true
	}
}

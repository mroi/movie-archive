import XCTest

@testable import MovieArchiveModel
@testable import MovieArchiveImporters
@testable import MovieArchiveConverter


/* MARK: Generic Importer Tests */

class ImporterTests: XCTestCase {

	func testUnsupportedSource() async {
		let source = URL(fileURLWithPath: "/var/empty")
		await XCTAssertThrowsErrorAsync(try await Importer(source: source)) {
			XCTAssertEqual($0 as! Importer.Error, .sourceNotSupported)
		}
	}
}


/* MARK: DVD Importer Tests */

class DVDImporterTests: XCTestCase {

	/// The `Bundle` of this test class, can be used to access test resources.
	private var testBundle: Bundle { Bundle(for: type(of: self)) }

	func testReaderInitDeinit() async {
		let openCall = expectation(description: "open should be called")
		let closeCall = expectation(description: "close should be called")

		class ReaderMock: ConverterDVDReader {
			let openCall: XCTestExpectation
			let closeCall: XCTestExpectation

			init(withExpectations expectations: XCTestExpectation...) {
				openCall = expectations[0]
				closeCall = expectations[1]
			}
			func open(_: URL, completionHandler done: @escaping (UUID?) -> Void) {
				openCall.fulfill()
				done(UUID())
			}
			func close(_: UUID) {
				closeCall.fulfill()
			}
			func readInfo(_: UUID, completionHandler: @escaping (Data?) -> Void) {
				XCTFail()
			}
		}

		try! await ConverterConnection.withMocks(proxy: ReaderMock(withExpectations: openCall, closeCall)) {
			let source = URL(fileURLWithPath: ".")
			await XCTAssertNoThrowAsync(try await DVDReader(source: source))
		}

		await waitForExpectations(timeout: .infinity)
	}

	func testInfoError() async {
		let readCall = expectation(description: "read info should be called")

		class ReaderMock: ConverterDVDReader {
			let readCall: XCTestExpectation

			init(expectations: XCTestExpectation...) {
				readCall = expectations[0]
			}
			func open(_: URL, completionHandler done: @escaping (UUID?) -> Void) {
				done(UUID())
			}
			func close(_: UUID) {}
			func readInfo(_: UUID, completionHandler done: @escaping (Data?) -> Void) {
				readCall.fulfill()
				done(Data(base64Encoded: "broken archive"))
			}
		}

		try! await ConverterConnection.withMocks(proxy: ReaderMock(expectations: readCall)) {
			let source = URL(fileURLWithPath: ".")
			var reader: DVDReader?
			await XCTAssertNoThrowAsync(reader = try await DVDReader(source: source))
			XCTAssertNotNil(reader)
			await XCTAssertThrowsErrorAsync(try await reader!.info()) {
				XCTAssertEqual($0 as! ConverterError, .sourceReadError)
			}
		}

		await waitForExpectations(timeout: .infinity)
	}

	func testMinimalDVD() async {
		let iso = testBundle.url(forResource: "MinimalDVD", withExtension: "iso")!
		var importer: Importer?
		await XCTAssertNoThrowAsync(importer = try await Importer(source: iso))
		XCTAssertNotNil(importer)

		let transform = Transform(importer: importer!, exporter: NullExporter())

		var outputs = 0
		let subscription = transform.publisher
			.mapError { _ in fatalError("unexpected publisher error") }
			.sink { _ in outputs += 1 }
		defer { subscription.cancel() }

		await transform.execute()

		await XCTAssertEqualAsync(await transform.state, .success)
		XCTAssertEqual(transform.description, "DVDImporter → NullExporter")
		XCTAssertEqual(outputs, 6)
	}
}

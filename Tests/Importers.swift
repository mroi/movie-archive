import XCTest

@testable import MovieArchiveModel
@testable import MovieArchiveImporters
@testable import MovieArchiveConverter


/* MARK: Generic Importer Tests */

class ImporterTests: XCTestCase {

	func testUnsupportedSource() {
		let source = URL(fileURLWithPath: "/var/empty")
		XCTAssertThrowsError(try Importer(source: source)) {
			XCTAssertEqual($0 as! Importer.Error, .sourceNotSupported)
		}
	}
}


/* MARK: DVD Importer Tests */

class DVDImporterTests: XCTestCase {

	/// The `Bundle` of this test class, can be used to access test resources.
	private var testBundle: Bundle { Bundle(for: type(of: self)) }

	func testReaderInitDeinit() {
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
			func readInfo(_: UUID, completionHandler: @escaping () -> Void) {
				XCTFail()
			}
		}

		try! ConverterClient.withMocks(proxy: ReaderMock(withExpectations: openCall, closeCall)) {
			let source = URL(fileURLWithPath: ".")
			XCTAssertNoThrow(try DVDReader(source: source))
		}

		waitForExpectations(timeout: .infinity)
	}

	func testInfoError() {
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
			func readInfo(_: UUID, completionHandler done: @escaping () -> Void) {
				readCall.fulfill()
				done()
			}
		}

		try! ConverterClient.withMocks(proxy: ReaderMock(expectations: readCall)) {
			let source = URL(fileURLWithPath: ".")
			var reader: DVDReader?
			XCTAssertNoThrow(reader = try DVDReader(source: source))
			XCTAssertNotNil(reader)
			XCTAssertThrowsError(try reader!.info()) {
				XCTAssertEqual($0 as! ConverterError, .sourceReadError)
			}
		}

		waitForExpectations(timeout: .infinity)
	}

	func testMinimalDVD() {
		let iso = testBundle.url(forResource: "MinimalDVD", withExtension: "iso")!
		var importer: Importer?
		XCTAssertNoThrow(importer = try Importer(source: iso))
		XCTAssertNotNil(importer)

		let transform = Transform(importer: importer!, exporter: NullExporter())
		transform.execute()
	}
}

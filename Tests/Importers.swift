import XCTest

@testable import MovieArchiveModel
@testable import MovieArchiveImporters
@testable import MovieArchiveExporters
@testable import MovieArchiveConverter


class ImporterTests: XCTestCase {

	func testUnsupportedSource() {
		let source = URL(fileURLWithPath: "/var/empty")
		XCTAssertThrowsError(try Importer(source: source)) {
			XCTAssertEqual($0 as! Importer.Error, Importer.Error.sourceNotSupported)
		}
	}

	func testXPCErrorPropagation() {
		// set up an invalid XPC connection
		let returnChannel = ReturnImplementation()
		let connection = NSXPCConnection(serviceName: "invalid")
		connection.remoteObjectInterface = NSXPCInterface(with: ConverterInterface.self)
		connection.invalidationHandler = { returnChannel.connectionInvalid() }
		connection.interruptionHandler = { returnChannel.connectionInterrupted() }
		connection.resume()

		// expect publisher to report the error
		let publisherFailure = expectation(description: "publisher should fail")
		let subscription = returnChannel.publisher.sink {
			XCTAssertEqual($0, .failure(.connectionInvalid))
			publisherFailure.fulfill()
		} receiveValue: { _ in }

		// exercise the invalid connection
		try! ConverterClient.withMocks(proxy: connection.remoteObjectProxy, publisher: returnChannel.publisher) {
			let source = URL(fileURLWithPath: "/var/empty")
			XCTAssertThrowsError(try Importer(source: source)) {
				XCTAssertEqual($0 as! Importer.Error, Importer.Error.connectionInvalid)
			}
		}
		waitForExpectations(timeout: .infinity)

		// cleanup
		subscription.cancel()
		connection.invalidate()
	}
}


class DVDImporterTests: XCTestCase {

	/// The `Bundle` of this test class, can be used to access test resources.
	private var testBundle: Bundle { Bundle(for: type(of: self)) }

	func testDVDReaderInitDeinit() {
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
			func readIFOs(withHandle: UUID, completionHandler: @escaping () -> Void) {
				XCTFail()
			}
		}

		ConverterClient.withMocks(proxy: ReaderMock(withExpectations: openCall, closeCall)) {
			let source = URL(fileURLWithPath: ".")
			XCTAssertNoThrow(try? DVDReader(source: source))
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

import XCTest

@testable import MovieArchiveConverter


/* MARK: Converter Tests */

class ConverterTests: XCTestCase {

	func testXPCErrorPropagation() {
		// set up an invalid XPC connection
		let returnChannel = ReturnImplementation()
		let connection = NSXPCConnection(serviceName: "invalid")
		connection.remoteObjectInterface = NSXPCInterface(with: ConverterTesting.self)
		connection.invalidationHandler = { returnChannel.sendConnectionInvalid() }
		connection.interruptionHandler = { returnChannel.sendConnectionInterrupted() }
		connection.resume()
		defer { connection.invalidate() }

		// expect publisher to report the error
		let publisherFailure = expectation(description: "publisher should fail")
		let subscription = returnChannel.publisher.sink(
			receiveCompletion: {
				XCTAssertEqual($0, .failure(.connectionInvalid))
				publisherFailure.fulfill()
			},
			receiveValue: { _ in })
		defer { subscription.cancel() }

		// exercise the invalid connection
		ConverterClient.withMocks(proxy: connection.remoteObjectProxy, publisher: returnChannel.publisher) {
			let remote = connection.remoteObjectProxy as! ConverterTesting
			remote.doNothing()
		}

		waitForExpectations(timeout: .infinity)
	}

	func testXPCErrorWrapper() {
		class ErrorSender {
			private let returnChannel: ReturnImplementation
			init(channel: ReturnImplementation) { returnChannel = channel }
			func error() { returnChannel.sendConnectionInterrupted() }
		}
		class ErrorClient: ConverterClient<ErrorSender> {
			func test() throws {
				// test that this wrapper observes the published error and throws
				try withConnectionErrorHandling { (_: (Result<Void, ConverterError>) -> Void) in
					remote.error()
				}
				XCTFail("error handling should throw")
			}
		}

		let returnChannel = ReturnImplementation()
		let sender = ErrorSender(channel: returnChannel)
		try! ConverterClient.withMocks(proxy: sender, publisher: returnChannel.publisher) {
			XCTAssertThrowsError(try ErrorClient().test()) {
				XCTAssertEqual($0 as! ConverterError, .connectionInterrupted)
			}
		}
	}
}

@objc private protocol ConverterTesting {
	func doNothing()
}

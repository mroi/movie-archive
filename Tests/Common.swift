import XCTest

@testable import MovieArchiveConverter


/* MARK: Converter Tests */

class ConverterTests: XCTestCase {

	func testDeinitialization() {
		let deinitClient = expectation(description: "converter client should be released")
		let deinitReturn = expectation(description: "return channel should be released")

		class TestClient: ConverterClient<ConverterInterface> {
			let deinitClient: XCTestExpectation
			init(withExpectations expectations: XCTestExpectation...) {
				deinitClient = expectations[0]
			}
			deinit {
				deinitClient.fulfill()
			}
		}
		class TestReturn: ReturnImplementation {
			let deinitReturn: XCTestExpectation
			init(withExpectations expectations: XCTestExpectation...) {
				deinitReturn = expectations[0]
			}
			deinit {
				deinitReturn.fulfill()
			}
		}

		// do complicated stuff with client and return and check for proper release
		do {
			let client = TestClient(withExpectations: deinitClient)
			let returnChannel = TestReturn(withExpectations: deinitReturn)
			try! ConverterClient.withMocks(proxy: client.remote, publisher: returnChannel.publisher) {
				XCTAssertNoThrow(
					try client.withConnectionErrorHandling { done in
						done(.success(ConverterClient<ConverterInterface>()))
					}
				)
				returnChannel.sendConnectionInterrupted()
			}
		}

		waitForExpectations(timeout: .infinity)
	}

	func testMessagePropagation() {
		class MessageSender {
			private let returnChannel: ReturnImplementation
			init(channel: ReturnImplementation) { returnChannel = channel }
			func message() { returnChannel.sendMessage(level: .default, "test message") }
		}

		let returnChannel = ReturnImplementation()
		let sender = MessageSender(channel: returnChannel)
		var outputs = [ConverterOutput]()

		ConverterClient.withMocks(proxy: sender, publisher: returnChannel.publisher) {
			let client = ConverterClient<MessageSender>()
			let subscription = client.publisher
				.assertNoFailure()
				.sink { outputs.append($0) }
			defer { subscription.cancel() }

			client.remote.message()
		}

		XCTAssertEqual(outputs.count, 1)
		if case .message(let level, let text) = outputs[0] {
			XCTAssertEqual(level, .default)
			XCTAssertEqual(text, "test message")
		} else {
			XCTFail("unexpected publisher output")
		}
	}

	func testProgressPropagation() {
		class ProgressSender {
			private let id = UUID()
			private let returnChannel: ReturnImplementation
			init(channel: ReturnImplementation) { returnChannel = channel }
			func step(_ i: Int64, of n: Int64) {
				returnChannel.sendProgress(id: id, completed: i, total: n, description: "test")
			}
		}

		let returnChannel = ReturnImplementation()
		let sender = ProgressSender(channel: returnChannel)
		var outputs = [ConverterOutput]()

		ConverterClient.withMocks(proxy: sender, publisher: returnChannel.publisher) {
			let client = ConverterClient<ProgressSender>()
			let subscription = client.publisher
				.assertNoFailure()
				.sink { outputs.append($0) }
			defer { subscription.cancel() }

			client.remote.step(0, of: 0)

			XCTAssertEqual(outputs.count, 1)
			guard case .progress(let progress) = outputs[0] else {
				return XCTFail("unexpected publisher output")
			}
			XCTAssertEqual(progress.fractionCompleted, 0.0)
			XCTAssertEqual(progress.isIndeterminate, true)
			XCTAssertEqual(progress.isFinished, false)

			client.remote.step(1, of: 2)

			XCTAssertEqual(outputs.count, 1)
			XCTAssertEqual(progress.fractionCompleted, 0.5)
			XCTAssertEqual(progress.isIndeterminate, false)
			XCTAssertEqual(progress.isFinished, false)

			client.remote.step(2, of: 2)

			XCTAssertEqual(outputs.count, 1)
			XCTAssertEqual(progress.fractionCompleted, 1.0)
			XCTAssertEqual(progress.isIndeterminate, false)
			XCTAssertEqual(progress.isFinished, true)
		}
	}

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


/* MARK: Intercept Library Tests */

class InterceptTests: XCTestCase {

	struct Intercept {
		let dlopen: @convention(c) (UnsafePointer<CChar>?, Int32) -> UnsafeMutableRawPointer?

		init() {
			let handle = Darwin.dlopen("libintercept.dylib", RTLD_LOCAL)
			XCTAssertNotNil(handle)

			let dlopenSymbol = dlsym(handle, "dlopen")
			XCTAssertNotNil(dlopenSymbol)
			dlopen = unsafeBitCast(dlopenSymbol, to: type(of: dlopen))
		}
	}

	/// Access the functions of the intercept library.
	///
	/// The intercept library replaces or wraps functionality of `libSystem` to
	/// adapt the behavior of other libraries without the need to modify them.
	let intercept = Intercept()

	func testDlopen() {
		XCTAssertNotNil(intercept.dlopen("/usr/lib/libSystem.B.dylib", 0))
		XCTAssertNil(intercept.dlopen("not existing", 0))
	}
}

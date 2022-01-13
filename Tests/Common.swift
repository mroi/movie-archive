import XCTest

@testable import MovieArchiveModel
@testable import MovieArchiveConverter


/* MARK: Model Tests */

class ModelTests: XCTestCase {

	func testMediaTreeEditing() {
		var tree = MediaTree.collection(.init(children: [
			.opaque(.init(payload: 42)),
			.opaque(.init(payload: 23))
		]))
		XCTAssertEqual(tree.count, 3)
		XCTAssertNotNil(tree.collection)
		XCTAssertTrue(tree.contains(where: { $0.collection != nil }))
		XCTAssertTrue(tree.contains(where: { $0.opaque?.payload as? Int == 42 }))
		XCTAssertTrue(tree.contains(where: { $0.opaque?.payload as? Int == 23 }))
		tree.withOpaque { $0.children.removeAll() }
		XCTAssertEqual(tree.count, 3)  // nothing changed
		tree.withCollection { $0.children.removeLast() }
		XCTAssertEqual(tree.count, 2)
		tree.modifyFirst(where: { $0.opaque?.payload as? Int == 42 }) {
			$0.withOpaque { $0.payload = 17 }
		}
		XCTAssertEqual(tree.count, 2)
		XCTAssertNotNil(tree.collection)
		XCTAssertEqual(tree.collection?.children.count, 1)
		XCTAssertEqual(tree.collection?.children.first?.opaque?.payload as? Int, 17)
	}

	func testMediaTreeJSON() {
		struct TestPayload: Codable, CustomJSONEmptyCollectionSkipping {
			var someOptional: Int? = 42
			var noneOptional: Int? = nil
			var emptyArray: [Int] = []
			var emptyDictionary: [Int: Int] = [:]
		}
		let expectedOutput = """
			{
			    "collection" : [
			        {
			            "opaque" : {
			                "id" : 0,
			                "payload" : {
			                    "TestPayload" : { "someOptional" : 42 }
			                }
			            }
			        }
			    ]
			}

			"""
		
		MediaTree.ID.allocator = MediaTree.ID.Allocator()
		let tree = MediaTree.collection(.init(children: [
			.opaque(.init(payload: TestPayload()))
		]))

		var json: JSON<MediaTree>!
		XCTAssertNoThrow(json = try tree.json())
		XCTAssertEqual(json.string(tabsAs: .spaces(width: 4)), expectedOutput)

		XCTAssertThrowsError(try json.mediaTree()) {
			XCTAssertNotNil($0 as? UnknownTypeError)
		}

		var decoded: MediaTree!
		let types = [TestPayload.self, TestPayload.self]  // testing non-unique elements
		XCTAssertNoThrow(decoded = try json.mediaTree(withTypes: types))
		var json2: JSON<MediaTree>!
		XCTAssertNoThrow(json2 = try decoded.json())
		XCTAssertEqual(json.data, json2.data)
	}

	func testErrorToPublisher() {
		let error = expectation(description: "an error should be published")

		let importer = ThrowingImporter()
		let exporter = NullExporter()
		let transform = Transform(importer: importer, exporter: exporter)
		XCTAssertEqual(transform.description, "ThrowingImporter → NullExporter")

		var outputs = 0
		let subscription = transform.publisher.sink(
			receiveCompletion: { if case .failure = $0 { error.fulfill() } },
			receiveValue: { _ in outputs += 1 })
		defer { subscription.cancel() }

		transform.execute()

		XCTAssertEqual(outputs, 1)
		waitForExpectations(timeout: .infinity)
	}
}


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
			func exercise() { returnChannel.sendMessage(level: .default, "test") }
			func error() { returnChannel.sendConnectionInterrupted() }
		}
		class ErrorClient: ConverterClient<ErrorSender> {
			func test() throws {
				// test that this wrapper observes the published error and throws
				try withConnectionErrorHandling { (_: (Result<Void, ConverterError>) -> Void) in
					remote.exercise()
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

	func testErrorLocalization() {
		XCTAssertNotNil(ConverterError.sourceNotSupported.errorDescription)
		XCTAssertNotNil(ConverterError.sourceReadError.errorDescription)
		XCTAssertNotNil(ConverterError.connectionInvalid.errorDescription)
		XCTAssertNotNil(ConverterError.connectionInterrupted.errorDescription)
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
		XCTAssertNil(intercept.dlopen("libdvdcss.2.dylib", 0))
		XCTAssertNil(intercept.dlopen("not existing", 0))
	}
}

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

		let tree = MediaTree.ID.$allocator.withValue(MediaTree.ID.Allocator()) {
			MediaTree.collection(.init(children: [
				.opaque(.init(payload: TestPayload()))
			]))
		}

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

	func testPassExecution() async {
		let importer = TestImporter(.opaque(.init(payload: 42))) {
			Test.Identity()
			Base.Loop {
				Test.Countdown(3)
				Test.Identity()
			}
			Base.If({ $0.allSatisfy { $0.opaque != nil } }) {
				Test.Identity()
			}
			Base.While(Test.Countdown(4)) {
				Test.Identity()
			}
		}
		let exporter = NullExporter()
		let transform = Transform(importer: importer, exporter: exporter)
		XCTAssertEqual(transform.description, "TestImporter → NullExporter")

		var outputs = 0
		let subscription = transform.publisher
			.mapError { _ in fatalError("unexpected publisher error") }
			.sink { _ in outputs += 1 }
		defer { subscription.cancel() }

		await transform.execute()

		XCTAssertEqual(outputs, 43)
	}

	func testClientInteraction() async {
		let importer = ThrowingImporter()
		let exporter = NullExporter()
		let transform = Transform(importer: importer, exporter: exporter)
		XCTAssertEqual(transform.description, "ThrowingImporter → NullExporter")

		let subscription = transform.publisher
			.mapError { _ in fatalError("unexpected publisher error") }
			.sink {
				if case .mediaTree(let interaction) = $0 {
					if let node = interaction.opaque {
						XCTAssertEqual(node.children.count, 0)
						XCTAssertEqual(node.payload as? Int, 42)
						interaction.value = .collection(.init(children: []))
						interaction.finish()
					} else {
						XCTFail("unexpected media tree")
					}
				} else {
					XCTFail("unexpected value")
				}
			}
		defer { subscription.cancel() }

		var mediaTree = MediaTree.opaque(.init(payload: 42))
		await transform.clientInteraction(&mediaTree) { .mediaTree($0) }
		XCTAssertNotNil(mediaTree.collection)
	}

	func testErrorToPublisher() async {
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

		await transform.execute()

		XCTAssertEqual(outputs, 1)
		await XCTAssertEqualAsync(await transform.state, .error)
		await waitForExpectations(timeout: .infinity)
	}

	func testCancellation() async {
		let cancelled = expectation(description: "transform should be cancelled")

		let importer = ThrowingImporter()
		let exporter = NullExporter()
		let transform = Transform(importer: importer, exporter: exporter)
		XCTAssertEqual(transform.description, "ThrowingImporter → NullExporter")

		let subscription = transform.publisher.sink(
			receiveCompletion: {
				if case .failure(let error) = $0, error is CancellationError {
					cancelled.fulfill()
				} else {
					XCTFail("unexpected completion")
				}
			},
			receiveValue: { _ in XCTFail("unexpected value") })
		defer { subscription.cancel() }

		withUnsafeCurrentTask { $0?.cancel() }
		await transform.execute()

		await XCTAssertEqualAsync(await transform.state, .error)
		await waitForExpectations(timeout: .infinity)
	}
}


/* MARK: Converter Tests */

class ConverterTests: XCTestCase {

	func testDeinitialization() async {
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
			try! await ConverterClient.withMocks(proxy: client.remote, publisher: returnChannel.publisher) {
				await XCTAssertNoThrowAsync(
					try await client.withConnectionErrorHandling { done in
						done(.success(ConverterClient<ConverterInterface>()))
					}
				)
				returnChannel.sendConnectionInterrupted()
			}
		}

		await waitForExpectations(timeout: .infinity)
	}

	func testMessagePropagation() async {
		class MessageSender {
			private let returnChannel: ReturnImplementation
			init(channel: ReturnImplementation) { returnChannel = channel }
			func message() { returnChannel.sendMessage(level: .default, "test message") }
		}

		let returnChannel = ReturnImplementation()
		let sender = MessageSender(channel: returnChannel)
		var outputs = [ConverterOutput]()

		await ConverterClient.withMocks(proxy: sender, publisher: returnChannel.publisher) {
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

	func testProgressPropagation() async {
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

		await ConverterClient.withMocks(proxy: sender, publisher: returnChannel.publisher) {
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

	func testXPCErrorPropagation() async {
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
		await ConverterClient.withMocks(proxy: connection.remoteObjectProxy, publisher: returnChannel.publisher) {
			let remote = connection.remoteObjectProxy as! ConverterTesting
			remote.doNothing()
		}

		await waitForExpectations(timeout: .infinity)
	}

	func testXPCErrorWrapper() async {
		class ErrorSender {
			private let returnChannel: ReturnImplementation
			init(channel: ReturnImplementation) { returnChannel = channel }
			func exercise() { returnChannel.sendMessage(level: .default, "test") }
			func error() { returnChannel.sendConnectionInterrupted() }
		}
		class ErrorClient: ConverterClient<ErrorSender> {
			func test() async throws {
				// test that this wrapper observes the published error and throws
				try await withConnectionErrorHandling { (_: (Result<Void, ConverterError>) -> Void) in
					remote.exercise()
					remote.error()
				}
				XCTFail("error handling should throw")
			}
		}

		let returnChannel = ReturnImplementation()
		let sender = ErrorSender(channel: returnChannel)
		try! await ConverterClient.withMocks(proxy: sender, publisher: returnChannel.publisher) {
			await XCTAssertThrowsErrorAsync(try await ErrorClient().test()) {
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


/* MARK: JSON Coding Tests */

class JSONCodingTests: XCTestCase {

	func testKeyedContainer() {
		struct Test: Codable, Equatable {
			var string = "test"
			var int: Int = 0
			var int8: Int8 = 0
			var int16: Int16 = 0
			var int32: Int32 = 0
			var int64: Int64 = 0
			var uint: UInt = 0
			var uint8: UInt8 = 0
			var uint16: UInt16 = 0
			var uint32: UInt32 = 0
			var uint64: UInt64 = 0
			var double: Double = 0
			var float: Float = 0
			var bool = false
		}
		XCTAssertNoThrow(XCTAssertEqual(try JSON(Test()).decode(), Test()))
	}

	func testUnkeyedContainer() {
		struct Test: Codable, CustomJSONCodable, Equatable {
			var string = "test"
			var int: Int = 0
			var int8: Int8 = 0
			var int16: Int16 = 0
			var int32: Int32 = 0
			var int64: Int64 = 0
			var uint: UInt = 0
			var uint8: UInt8 = 0
			var uint16: UInt16 = 0
			var uint32: UInt32 = 0
			var uint64: UInt64 = 0
			var double: Double = 0
			var float: Float = 0
			var bool = false
			init() {}
			func encode(toCustomJSON encoder: Encoder) throws {
				var container = encoder.unkeyedContainer()
				let _ = container.nestedContainer(keyedBy: CodingKeys.self)
				let _ = container.nestedUnkeyedContainer()
				try container.encode(string)
				try container.encode(int)
				try container.encode(int8)
				try container.encode(int16)
				try container.encode(int32)
				try container.encode(int64)
				try container.encode(uint)
				try container.encode(uint8)
				try container.encode(uint16)
				try container.encode(uint32)
				try container.encode(uint64)
				try container.encode(double)
				try container.encode(float)
				try container.encode(bool)
				try container.encodeNil()
			}
			init(fromCustomJSON decoder: Decoder) throws {
				var container = try decoder.unkeyedContainer()
				let _ = try container.nestedContainer(keyedBy: CodingKeys.self)
				let _ = try container.nestedUnkeyedContainer()
				string = try container.decode(String.self)
				int = try container.decode(Int.self)
				int8 = try container.decode(Int8.self)
				int16 = try container.decode(Int16.self)
				int32 = try container.decode(Int32.self)
				int64 = try container.decode(Int64.self)
				uint = try container.decode(UInt.self)
				uint8 = try container.decode(UInt8.self)
				uint16 = try container.decode(UInt16.self)
				uint32 = try container.decode(UInt32.self)
				uint64 = try container.decode(UInt64.self)
				double = try container.decode(Double.self)
				float = try container.decode(Float.self)
				bool = try container.decode(Bool.self)
				XCTAssertEqual(try container.decodeNil(), true)
			}
		}
		XCTAssertNoThrow(XCTAssertEqual(try JSON(Test()).decode(), Test()))
	}

	func testSingleValueContainer() {
		struct Test: Codable, Equatable {
			var arrayOfString = ["test"]
			var arrayOfInt: [Int] = [0]
			var arrayOfInt8: [Int8] = [0]
			var arrayOfInt16: [Int16] = [0]
			var arrayOfInt32: [Int32] = [0]
			var arrayOfInt64: [Int64] = [0]
			var arrayOfUint: [UInt] = [0]
			var arrayOfUint8: [UInt8] = [0]
			var arrayOfUint16: [UInt16] = [0]
			var arrayOfUint32: [UInt32] = [0]
			var arrayOfUint64: [UInt64] = [0]
			var arrayOfDouble: [Double] = [0]
			var arrayOfFloat: [Float] = [0]
			var arrayOfBool = [false]
			var arrayOfNull: [Bool?] = [nil]
		}
		XCTAssertNoThrow(XCTAssertEqual(try JSON(Test()).decode(), Test()))
	}

	func testDecodingErrors() {
		struct Test: Codable, CustomJSONCodable, Equatable {
			var int = 0
			init() {}
			func encode(toCustomJSON encoder: Encoder) throws {
				try encode(to: encoder)
			}
			init(fromCustomJSON decoder: Decoder) throws {
				XCTAssertThrowsError(try decoder.unkeyedContainer())
				let container = try decoder.container(keyedBy: CodingKeys.self)
				XCTAssertThrowsError(try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .int))
				XCTAssertThrowsError(try container.nestedUnkeyedContainer(forKey: .int))
				XCTAssertThrowsError(try container.decode(String.self, forKey: .int))
				try self.init(from: decoder)
			}
		}
		XCTAssertNoThrow(XCTAssertEqual(try JSON(Test()).decode(), Test()))
	}
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

import Testing
import Foundation

@testable import MovieArchiveModel
@testable import MovieArchiveConverter


/* MARK: Model Tests */

@Suite
struct ModelTests {

	@Test
	func mediaTreeEditing() {
		var tree = MediaTree.collection(.init(children: [
			.opaque(.init(payload: 42)),
			.opaque(.init(payload: 23))
		]))
		#expect(tree.count == 3)
		#expect(tree.collection != nil)
		#expect(tree.contains(where: { $0.collection != nil }))
		#expect(tree.contains(where: { $0.opaque?.payload as? Int == 42 }))
		#expect(tree.contains(where: { $0.opaque?.payload as? Int == 23 }))
		tree.withOpaque { $0.children.removeAll() }
		#expect(tree.count == 3)  // nothing changed
		tree.withCollection { $0.children.removeLast() }
		#expect(tree.count == 2)
		tree.modifyFirst(where: { $0.opaque?.payload as? Int == 42 }) {
			$0.withOpaque { $0.payload = 17 }
		}
		#expect(tree.count == 2)
		#expect(tree.collection != nil)
		#expect(tree.collection?.children.count == 1)
		#expect(tree.collection?.children.first?.opaque?.payload as? Int == 17)
	}

	@Test
	func mediaTreeJSON() async throws {
		struct TestPayload: Codable, CustomJSON.EmptyCollectionSkipping {
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

		// encode media tree to JSON and compare with expected output
		let json = try tree.json()
		#expect(json.string(tabsAs: .spaces(width: 4)) == expectedOutput)

		// decoding without registering payload types fails
		#expect(throws: UnknownTypeError.self) {
			try json.mediaTree()
		}

		// decoding with type knowledge succeeds
		let types = (TestPayload.self, TestPayload.self)  // testing non-unique elements
		let decoded = try json.mediaTree(withTypes: types.0, types.1)

		// decoded result re-encodes to the original JSON
		let json2 = try decoded.json()
		#expect(json.data == json2.data)

		// JSON can be stored and read
		let fileManager = FileManager.default
		let testUrl = fileManager.temporaryDirectory.appendingPathComponent("test.json.gz")
		try await json2.write(to: testUrl)
		let json3 = try await JSON<MediaTree>(contentsOf: testUrl)
		#expect(json.data == json3.data)
		try fileManager.removeItem(at: testUrl)

		// reading an empty file fails
		let emptyUrl = fileManager.temporaryDirectory.appendingPathComponent("empty.json.gz")
		fileManager.createFile(atPath: emptyUrl.path, contents: nil)
		let error = await #expect(throws: (any Error).self) {
			try await JSON<MediaTree>(contentsOf: emptyUrl)
		}
		#expect(String(describing: try #require(error)) == "Inappropriate file type or format")
		try fileManager.removeItem(at: emptyUrl)
	}

	@Test
	func passExecution() async {
		let importer = TestImporter(.opaque(.init(payload: 42))) {
			Test.Identity()
			Compose.Loop {
				Test.Countdown(3)
				Test.Identity()
			}
			Compose.If({ $0.allSatisfy { $0.opaque != nil } }) {
				Test.Identity()
			}
			Compose.While(Test.Countdown(4)) {
				Test.Identity()
			}
		}
		let exporter = NullExporter()
		let transform = Transform(importer: importer, exporter: exporter)
		#expect(transform.description == "TestImporter → NullExporter")

		var outputs = 0
		let subscription = transform.publisher
			.mapError { _ in fatalError("unexpected publisher error") }
			.sink { _ in outputs += 1 }
		defer { subscription.cancel() }

		await transform.execute()

		#expect(outputs == 43)
	}

	@Test
	func clientInteraction() async {
		let importer = TestImporter(.opaque(.init(payload: 42))) {
			Compose.MediaTreeInteraction()
		}
		let exporter = NullExporter()
		let transform = Transform(importer: importer, exporter: exporter)
		#expect(transform.description == "TestImporter → NullExporter")

		var mediaTree: MediaTree?
		let subscription = transform.publisher
			.mapError { _ in fatalError("unexpected publisher error") }
			.sink {
				if case .mediaTree(let interaction) = $0 {
					if let node = interaction.opaque {
						#expect(node.children.count == 0)
						#expect(node.payload as? Int == 42)
						interaction.value = .collection(.init(children: []))
						interaction.finish()
					} else {
						mediaTree = interaction.value
					}
				}
			}
		defer { subscription.cancel() }

		await transform.execute()

		#expect(mediaTree?.collection != nil)
	}

	@Test
	func errorToPublisher() async {
		let importer = ThrowingImporter()
		let exporter = NullExporter()
		let transform = Transform(importer: importer, exporter: exporter)
		#expect(transform.description == "ThrowingImporter → NullExporter")

		var outputs = 0
		await confirmation("an error should be published") { error in
			let subscription = transform.publisher.sink(
				receiveCompletion: { if case .failure = $0 { error.confirm() } },
				receiveValue: { _ in outputs += 1 })
			defer { subscription.cancel() }

			await transform.execute()
		}

		#expect(outputs == 1)
		#expect(await transform.state == .error)
	}

	@Test
	func cancellation() async {
		let importer = ThrowingImporter()
		let exporter = NullExporter()
		let transform = Transform(importer: importer, exporter: exporter)
		#expect(transform.description == "ThrowingImporter → NullExporter")

		await confirmation("transform should be cancelled") { cancelled in
			let task = Task {
				let subscription = transform.publisher.sink(
					receiveCompletion: {
						if case .failure(let error) = $0, error is CancellationError {
							cancelled.confirm()
						} else {
							Issue.record("unexpected completion")
						}
					},
					receiveValue: { _ in Issue.record("unexpected value") })
				defer { subscription.cancel() }

				withUnsafeCurrentTask { $0?.cancel() }
				await transform.execute()
			}
			await task.value  // wait for task completion
		}

		#expect(await transform.state == .error)
	}
}


/* MARK: Converter Tests */

@Suite
struct ConverterTests {

	@Test
	func deinitialization() async throws {
		try await confirmation("converter client should be released") { deinitClient in
			try await confirmation("return channel should be released") { deinitReturn in

				class TestClient: ConverterConnection<ConverterInterface> {
					let deinitClient: Confirmation
					init(deinit: Confirmation) {
						deinitClient = `deinit`
					}
					deinit {
						deinitClient.confirm()
					}
				}
				class TestReturn: ReturnImplementation {
					let deinitReturn: Confirmation
					init(deinit: Confirmation) {
						deinitReturn = `deinit`
					}
					deinit {
						deinitReturn.confirm()
					}
				}
				
				// do complicated stuff with client and return and check for proper release
				let client = TestClient(deinit: deinitClient)
				let returnChannel = TestReturn(deinit: deinitReturn)
				try await ConverterConnection.withUnsafeMocks(proxy: client.remote, publisher: returnChannel.publisher) {
					let _ = try await client.withErrorHandling { _, done in
						done(.success(ConverterConnection<ConverterInterface>()))
					}
					returnChannel.sendConnectionInterrupted()
				}
			}
		}
	}

	@Test
	func messagePropagation() async {
		class MessageSender {
			private let returnChannel: ReturnImplementation
			init(channel: ReturnImplementation) { returnChannel = channel }
			func message() { returnChannel.sendMessage(level: .default, "test message") }
		}

		let returnChannel = ReturnImplementation()
		let sender = MessageSender(channel: returnChannel)
		var outputs = [ConverterOutput]()

		await ConverterConnection.withUnsafeMocks(proxy: sender, publisher: returnChannel.publisher) {
			let client = ConverterConnection<MessageSender>()
			let subscription = client.publisher
				.assertNoFailure()
				.sink { outputs.append($0) }
			defer { subscription.cancel() }

			client.remote.message()
		}

		#expect(outputs.count == 1)
		if case .message(let level, let text) = outputs[0] {
			#expect(level == .default)
			#expect(text == "test message")
		} else {
			Issue.record("unexpected publisher output")
		}
	}

	@Test
	func progressPropagation() async {
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

		await ConverterConnection.withUnsafeMocks(proxy: sender, publisher: returnChannel.publisher) {
			let client = ConverterConnection<ProgressSender>()
			let subscription = client.publisher
				.assertNoFailure()
				.sink { outputs.append($0) }
			defer { subscription.cancel() }

			client.remote.step(0, of: 0)

			#expect(outputs.count == 1)
			guard case .progress(let progress) = outputs[0] else {
				fatalError("unexpected publisher output")
			}
			#expect(progress.fractionCompleted == 0.0)
			#expect(progress.isIndeterminate == true)
			#expect(progress.isFinished == false)

			client.remote.step(1, of: 2)

			#expect(outputs.count == 1)
			#expect(progress.fractionCompleted == 0.5)
			#expect(progress.isIndeterminate == false)
			#expect(progress.isFinished == false)

			client.remote.step(2, of: 2)

			#expect(outputs.count == 1)
			#expect(progress.fractionCompleted == 1.0)
			#expect(progress.isIndeterminate == false)
			#expect(progress.isFinished == true)
		}
	}

	@Test
	func xpcErrorPropagation() async {
		// set up an invalid XPC connection
		let returnChannel = ReturnImplementation()
		let connection = NSXPCConnection(serviceName: "invalid")
		connection.remoteObjectInterface = NSXPCInterface(with: ConverterTesting.self)
		connection.invalidationHandler = { returnChannel.sendConnectionInvalid() }
		connection.interruptionHandler = { returnChannel.sendConnectionInterrupted() }
		connection.resume()
		defer { connection.invalidate() }

		// expect publisher to report the error
		await confirmation("publisher should fail") { publisherFailure in
			let subscription = returnChannel.publisher.sink(
				receiveCompletion: {
					#expect($0 == .failure(.connectionInvalid))
					publisherFailure.confirm()
				},
				receiveValue: { _ in }
			)
			defer { subscription.cancel() }

			// exercise the invalid connection
			await ConverterConnection.withUnsafeMocks(proxy: connection.remoteObjectProxy, publisher: returnChannel.publisher) {
				let remote = connection.remoteObjectProxy as! ConverterTesting
				remote.doNothing()
			}
			// give asynchronous invalidation handlers time to run
			try? await Task.sleep(for: .milliseconds(100))
		}
	}

	@Test
	func xpcErrorWrapper() async {
		class ErrorSender {
			private let returnChannel: ReturnImplementation
			init(channel: ReturnImplementation) { returnChannel = channel }
			func exercise() { returnChannel.sendMessage(level: .default, "test") }
			func error() { returnChannel.sendConnectionInterrupted() }
		}
		class ErrorClient: ConverterConnection<ErrorSender> {
			func test() async throws {
				// test that this wrapper observes the published error and throws
				try await withErrorHandling { (_, _: (sending Result<Void, ConverterError>) -> Void) in
					remote.exercise()
					remote.error()
				}
				Issue.record("error handling should throw")
			}
		}

		let returnChannel = ReturnImplementation()
		let sender = ErrorSender(channel: returnChannel)
		await ConverterConnection.withUnsafeMocks(proxy: sender, publisher: returnChannel.publisher) {
			let error = await #expect(throws: ConverterError.self) {
				try await ErrorClient().test()
			}
			#expect(error == .connectionInterrupted)
		}
	}

	@Test
	func errorLocalization() {
		#expect(ConverterError.sourceNotSupported.errorDescription != nil)
		#expect(ConverterError.sourceReadError.errorDescription != nil)
		#expect(ConverterError.connectionInvalid.errorDescription != nil)
		#expect(ConverterError.connectionInterrupted.errorDescription != nil)
	}
}

@objc private protocol ConverterTesting {
	func doNothing()
}


/* MARK: JSON Coding Tests */

@Suite
struct JSONCodingTests {

	@Test
	func keyedContainer() throws {
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
		let decoded = try JSON(Test()).decode()
		#expect(decoded == Test())
	}

	@Test
	func unkeyedContainer() throws {
		struct Test: Codable, CustomJSON.Codable, Equatable {
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
				#expect(try container.decodeNil() == true)
			}
		}
		let decoded = try JSON(Test()).decode()
		#expect(decoded == Test())
	}

	@Test
	func singleValueContainer() throws {
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
		let decoded = try JSON(Test()).decode()
		#expect(decoded == Test())
	}

	@Test
	func decodingErrors() throws {
		struct Test: Codable, CustomJSON.Codable, Equatable {
			var int = 0
			init() {}
			func encode(toCustomJSON encoder: Encoder) throws {
				try encode(to: encoder)
			}
			init(fromCustomJSON decoder: Decoder) throws {
				#expect(throws: DecodingError.self) {
					try decoder.unkeyedContainer()
				}
				let container = try decoder.container(keyedBy: CodingKeys.self)
				#expect(throws: DecodingError.self) {
					try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .int)
				}
				#expect(throws: DecodingError.self) {
					try container.nestedUnkeyedContainer(forKey: .int)
				}
				#expect(throws: DecodingError.self) {
					try container.decode(String.self, forKey: .int)
				}
				try self.init(from: decoder)
			}
		}
		let decoded = try JSON(Test()).decode()
		#expect(decoded == Test())
	}
}


/* MARK: Intercept Library Tests */

@Suite
struct InterceptTests {

	struct Intercept {
		let dlopen: @convention(c) (UnsafePointer<CChar>?, Int32) -> UnsafeMutableRawPointer?

		init() {
			let handle = Darwin.dlopen("libintercept.dylib", RTLD_LOCAL)
			#expect(handle != nil)

			let dlopenSymbol = dlsym(handle, "dlopen")
			#expect(dlopenSymbol != nil)
			dlopen = unsafeBitCast(dlopenSymbol, to: type(of: dlopen))
		}
	}

	/// Access the functions of the intercept library.
	///
	/// The intercept library replaces or wraps functionality of `libSystem` to
	/// adapt the behavior of other libraries without the need to modify them.
	let intercept = Intercept()

	@Test
	func dlopen() {
		#expect(intercept.dlopen("/usr/lib/libSystem.B.dylib", 0) != nil)
		#expect(intercept.dlopen("libdvdcss.2.dylib", 0) == nil)
		#expect(intercept.dlopen("not existing", 0) == nil)
	}
}

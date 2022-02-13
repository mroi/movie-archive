import Foundation
import System
import zlib


/* MARK: JSON Data */

/// JSON representation and compressed file storage.
public struct JSON<Root: Codable>: Sendable {
	public let data: Data

	init(_ root: Root) throws {
		let encoder = CustomJSONEncoder()
		data = try encoder.encode(root)
	}

	func decode() throws -> Root {
		let decoder = CustomJSONDecoder()
		return try decoder.decode(Root.self, from: data)
	}
}

extension JSON {

	/// Convert the JSON data into a string with configurable indentation.
	public func string(tabsAs format: TabFormat = .tabs) -> String {
		var result = String(data: data, encoding: .utf8)!
		if case .spaces(let width) = format {
			let lines = result.split(separator: "\n")
			let spaceIndented = lines.map { line in
				let firstNonTab = line.firstIndex(where: { !$0.isWhitespace }) ?? line.startIndex
				let tabCount = line[..<firstNonTab].count
				let spaces = String(repeating: " ", count: width * tabCount)
				return spaces + line[firstNonTab...]
			}
			result = spaceIndented.joined(separator: "\n") + "\n"
		}
		return result
	}

	public enum TabFormat {
		case tabs
		case spaces(width: Int)
	}
}

extension JSON {

	/// Writes the JSON data to a compressed file.
	///
	/// The file extension of `.json.gz` is appended to the URL automatically.
	///
	/// - Throws: `Errno` in case of file system errors.
	public func write(to url: URL) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			let task = Task {
				let file = try FileDescriptor.open(JSON.path(from: url), .writeOnly,
				                                   options: [ .create, .truncate ],
				                                   permissions: FilePermissions(rawValue: 0o644))
				defer { try? file.close() }

				var stream = z_stream()
				let enableGzipHeader: Int32 = 16
				var result = deflateInit2_(&stream, Z_BEST_COMPRESSION, Z_DEFLATED,
				                           enableGzipHeader + MAX_WBITS, MAX_MEM_LEVEL,
				                           Z_DEFAULT_STRATEGY, ZLIB_VERSION,
				                           Int32(MemoryLayout<z_stream>.size))
				assert(result == Z_OK)
				defer { deflateEnd(&stream) }

				let output = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 256 * 1024)
				defer { output.deallocate() }

				try data.withUnsafeBytes { bytes in
					let pointer = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
					stream.next_in = pointer.map(UnsafeMutablePointer.init)
					stream.avail_in = UInt32(bytes.count)

					repeat {
						stream.next_out = output.baseAddress
						stream.avail_out = UInt32(output.count)

						let finish = stream.avail_in > 0 ? Z_NO_FLUSH : Z_FINISH
						result = deflate(&stream, finish)
						assert(result == Z_OK || result == Z_STREAM_END)

						let produced = output.count - Int(stream.avail_out)
						try file.writeAll(output.prefix(produced))
					} while result != Z_STREAM_END
				}
				assert(stream.avail_in == 0)  // all input has been consumed
			}
			Task { continuation.resume(with: await task.result) }
		}
	}

	/// Reads JSON data from a compressed file.
	///
	/// The file extension of `.json.gz` is appended to the URL automatically.
	///
	/// - Throws: `Errno` in case of file system errors;
	///   `Errno.badFileTypeOrFormat` if the compressed file is malformed.
	init(contentsOf url: URL) async throws {
		data = try await withCheckedThrowingContinuation { continuation in
			let task = Task {
				let file = try FileDescriptor.open(JSON.path(from: url), .readOnly)
				defer { try? file.close() }

				var stream = z_stream()
				let enableGzipHeader: Int32 = 32
				var result = inflateInit2_(&stream, enableGzipHeader + MAX_WBITS,
				                           ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
				assert(result == Z_OK)
				defer { inflateEnd(&stream) }

				let input = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 256 * 1024)
				defer { input.deallocate() }
				let output = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 256 * 1024)
				defer { output.deallocate() }

				var data = Data()
				repeat {
					let readCount = try file.read(into: UnsafeMutableRawBufferPointer(input))
					stream.next_in = input.baseAddress
					stream.avail_in = UInt32(readCount)

					repeat {
						stream.next_out = output.baseAddress
						stream.avail_out = UInt32(output.count)

						result = inflate(&stream, Z_NO_FLUSH)
						guard result == Z_OK || result == Z_STREAM_END else {
							throw Errno.badFileTypeOrFormat
						}

						let produced = output.count - Int(stream.avail_out)
						data.append(contentsOf: output.prefix(produced))
					} while stream.avail_out == 0
				} while result != Z_STREAM_END

				return data
			}
			Task { continuation.resume(with: await task.result) }
		}
	}

	static private func path(from url: URL) throws -> FilePath {
		// ensure enclosing directory exists
		let directory = url.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

		// ensure file extensions
		var url = url
		if url.pathExtension == "gz" { url.deletePathExtension() }
		if url.pathExtension == "json" { url.deletePathExtension() }
		url.appendPathExtension("json")
		url.appendPathExtension("gz")

		// convert to FilePath
		guard let path = FilePath(url) else { throw Errno.noSuchFileOrDirectory }
		return path
	}
}


/* MARK: Custom JSON Coding */

/// Types can adopt this protocol to customize their JSON representation.
///
/// You can still delegate to the original, synthesized functions from `Codable`.
/// Only the JSON encoding and decoding performed by the `JSON` type respects
/// these customizations.
public protocol CustomJSONCodable {
	func encode(toCustomJSON encoder: any Encoder) throws
	init(fromCustomJSON decoder: any Decoder) throws
}


/// Types can adopt this protocol to enable skipping of empty collections.
///
/// For brevity and JSON readability, some types can benefit from not storing
/// empty collections. Instead, the entire key-value pair containing an empty
/// collection is skipped. Only the JSON encoding and decoding performed by the
/// `JSON` type respects these customizations.
///
/// This behavior is opt-in, since it can lead to ambiguities during decoding
/// when applied universally. A good indicator for a type that should **not**
/// adopt this behavior is inspection of `allKeys` in the decoding initializers.
public protocol CustomJSONEmptyCollectionSkipping: Codable, CustomJSONCodable {}

extension CustomJSONEmptyCollectionSkipping {
	public func encode(toCustomJSON encoder: Encoder) throws {
		try encode(to: encoder)
		try encoder.skipEmptyCollections()
	}
	public init(fromCustomJSON decoder: Decoder) throws {
		try decoder.enableMissingAsEmpty()
		try self.init(from: decoder)
	}
}

/// Types can adopt this protocol to enable more readable dictionary coding.
///
/// By default, dictionaries are encoded to JSON arrays that alternate between
/// storing a key and a value. This is not very intuitive to read. However, if
/// the dictionary’s key type adopts this protocol, it declares that it can
/// encode and decode itself against a string. Strings can be used directly as
/// JSON keys, allowing a readable JSON representation of the dictionary.
///
/// Furthermore, the same string representation can be used to encode all
/// instances of the adopting type. All that is needed is to additionally
/// declare `CustomJSONCodable` conformance.
///
/// - Remark: A similar dictionary coding customization could be achieved with
///   the standard library’s `CodingKeyRepresentable` protocol. However,
///   adopting this protocol requires more boilerplate (a `CodingKey` type) and
///   changes the dictionary representation app-wide, not just for custom JSON.
public protocol CustomJSONStringKeyRepresentable: Comparable {
	var stringValue: String { get }
	init?(stringValue: String)
}

extension CustomJSONStringKeyRepresentable {
	public func encode(toCustomJSON encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(stringValue)
	}
	public init(fromCustomJSON decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		guard let result = Self(stringValue: try container.decode(String.self)) else {
			throw DecodingError.typeMismatch(Self.self, .init(codingPath: container.codingPath,
				debugDescription: "value of type \(Self.self) expected"))
		}
		self = result
	}
}

extension Dictionary: CustomJSONCodable where Key: CustomJSONStringKeyRepresentable, Value: Codable {
	// custom encoding: string-representable keys as direct string keys
	struct StringKeys: CodingKey {
		let stringValue: String
		var intValue: Int? { Int(stringValue) }
		init(stringValue: String) { self.stringValue = stringValue }
		init(intValue: Int) { self.stringValue = String(intValue) }
	}

	public func encode(toCustomJSON encoder: Encoder) throws {
		var container = encoder.container(keyedBy: StringKeys.self)
		let sortedKeys = keys.sorted()
		for key in sortedKeys {
			try container.encode(self[key]!, forKey: StringKeys(stringValue: key.stringValue))
		}
	}

	public init(fromCustomJSON decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: StringKeys.self)
		self.init(minimumCapacity: container.allKeys.count)
		for key in container.allKeys {
			guard let index = Key(stringValue: key.stringValue) else {
				throw DecodingError.typeMismatch(Key.self,
					.init(codingPath: container.codingPath + [key],
						debugDescription: "key of type \(Key.self) expected"))
			}
			self[index] = try container.decode(Value.self, forKey: key)
		}
	}
}


/* MARK: Custom JSON Encoder */

/// A JSON encoder with customizable behavior.
///
/// This encoder implements the following differences compared to the standard
/// `JSONEncoder`:
/// * retain element order in dictionary collections
/// * rendering of reasonably short collections in a single line
/// * respect `CustomJSONCodable` to customize JSON encoding of types
private struct CustomJSONEncoder {

	/// Reference-typed storage box.
	///
	/// Because this is reference-typed, by recursively adding sub-storages and
	/// passing them into sub-encoders, we simultaneously build up the final
	/// tree in the top-level storage.
	///
	/// Conformance to different protocols depends on the `Value` type parameter:
	/// * `ElementStorage` conforms to `Encoder` and `SingleValueEncodingContainer`
	/// * `ArrayStorage` conforms to `UnkeyedEncodingContainer`
	/// * `KeyedDictionaryStorage` conforms to `KeyedEncodingContainerProtocol`
	class Storage<Value> {
		let codingPath: [any CodingKey]
		var store: Value
		init(codingPath: [any CodingKey], store: Value) {
			self.codingPath = codingPath
			self.store = store
		}
	}

	/// Subclass to remember `Key` type for `KeyedEncodingContainerProtocol`
	class KeyedDictionaryStorage<Key: CodingKey>: DictionaryStorage {}

	typealias DictionaryStorage = Storage<Array<(key: any CodingKey, value: ElementStorage)>>
	typealias ArrayStorage = Storage<Array<ElementStorage>>
	typealias ElementStorage = Storage<Element?>

	enum Element {
		case dictionary(DictionaryStorage)
		case array(ArrayStorage)
		case string(String)
		case signedInteger(Int64)
		case unsignedInteger(UInt64)
		case float(Double)
		case boolean(Bool)
		case null
	}

	func encode<Root: Encodable>(_ root: Root) throws -> Data {
		let storage = ElementStorage(codingPath: [], store: nil)
		try storage.encode(root)
		return try storage.serialize() + "\n".utf8
	}
}

private extension CustomJSONEncoder.Storage {
	typealias KeyedDictionaryStorage = CustomJSONEncoder.KeyedDictionaryStorage
	typealias DictionaryStorage = CustomJSONEncoder.DictionaryStorage
	typealias ArrayStorage = CustomJSONEncoder.ArrayStorage
	typealias ElementStorage = CustomJSONEncoder.ElementStorage
	typealias Element = CustomJSONEncoder.Element
}

private extension CustomJSONEncoder.KeyedDictionaryStorage {
	func emptyDictionaryStorage<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey key: Key) -> KeyedDictionaryStorage<NestedKey> {
		let codingPath = codingPath + [key]
		let storage = KeyedDictionaryStorage<NestedKey>(codingPath: codingPath, store: [])
		store(key: key, value: .dictionary(storage))
		return storage
	}
	func emptyArrayStorage(forKey key: Key) -> ArrayStorage {
		let codingPath = codingPath + [key]
		let storage = ArrayStorage(codingPath: codingPath, store: [])
		store(key: key, value: .array(storage))
		return storage
	}
	func emptyElementStorage(forKey key: Key) -> ElementStorage {
		let codingPath = codingPath + [key]
		let storage = ElementStorage(codingPath: codingPath, store: nil)
		store(key: key, value: storage)
		return storage
	}
	/// - Important: This accessor checks invariants. All other accessors should
	///   funnel through here.
	func store(key: any CodingKey, value storage: ElementStorage) {
		precondition(!store.map(\.key.stringValue).contains(key.stringValue), "key already present")
		store.append((key: key, value: storage))
	}
	func store(key: any CodingKey, value element: Element) {
		let codingPath = codingPath + [key]
		let storage = ElementStorage(codingPath: codingPath, store: element)
		store(key: key, value: storage)
	}
}

private extension CustomJSONEncoder.ArrayStorage {
	struct ArrayCodingKey: CodingKey {
		let intValue: Int?
		var stringValue: String { "\(intValue!)" }
		init(stringValue: String) { intValue = Int(stringValue) }
		init(intValue: Int) { self.intValue = intValue }
	}
	func emptyDictionaryStorage<Key: CodingKey>(keyedBy _: Key.Type) -> KeyedDictionaryStorage<Key> {
		let codingPath = codingPath + [ArrayCodingKey(intValue: count)]
		let storage = KeyedDictionaryStorage<Key>(codingPath: codingPath, store: [])
		store(.dictionary(storage))
		return storage
	}
	func emptyArrayStorage() -> ArrayStorage {
		let codingPath = codingPath + [ArrayCodingKey(intValue: count)]
		let storage = ArrayStorage(codingPath: codingPath, store: [])
		store(.array(storage))
		return storage
	}
	func emptyElementStorage() -> ElementStorage {
		let codingPath = codingPath + [ArrayCodingKey(intValue: count)]
		let storage = ElementStorage(codingPath: codingPath, store: nil)
		store(storage)
		return storage
	}
	func store(_ storage: ElementStorage) {
		store.append(storage)
	}
	func store(_ element: Element) {
		let codingPath = codingPath + [ArrayCodingKey(intValue: count)]
		let storage = ElementStorage(codingPath: codingPath, store: element)
		store(storage)
	}
}

private extension CustomJSONEncoder.ElementStorage {
	func emptyDictionaryStorage<Key: CodingKey>(keyedBy _: Key.Type) -> KeyedDictionaryStorage<Key> {
		let storage = KeyedDictionaryStorage<Key>(codingPath: codingPath, store: [])
		store(.dictionary(storage))
		return storage
	}
	func emptyArrayStorage() -> ArrayStorage {
		let storage = ArrayStorage(codingPath: codingPath, store: [])
		store(.array(storage))
		return storage
	}
	/// - Important: This accessor checks invariants. All other accessors should
	///   funnel through here.
	func store(_ element: Element) {
		precondition(store == nil, "element already encoded")
		store = element
	}
}

extension CustomJSONEncoder.ElementStorage: Encoder {
	var userInfo: [CodingUserInfoKey: Any] { [:] }

	func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
		return KeyedEncodingContainer(emptyDictionaryStorage(keyedBy: type))
	}
	func unkeyedContainer() -> UnkeyedEncodingContainer {
		return emptyArrayStorage()
	}
	func singleValueContainer() -> SingleValueEncodingContainer {
		return self
	}
}

extension CustomJSONEncoder.KeyedDictionaryStorage: KeyedEncodingContainerProtocol {

	func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
		return KeyedEncodingContainer(emptyDictionaryStorage(keyedBy: type, forKey: key))
	}
	func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
		return emptyArrayStorage(forKey: key)
	}
	func superEncoder() -> Encoder {
		return emptyElementStorage(forKey: Key(stringValue: "super")!)
	}
	func superEncoder(forKey key: Key) -> Encoder {
		return emptyElementStorage(forKey: key)
	}

	func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
		let storage = emptyElementStorage(forKey: key)
		if let value = value as? CustomJSONCodable {
			try value.encode(toCustomJSON: storage)
		} else {
			try value.encode(to: storage)
		}
	}

	func encode(_ value: String, forKey key: Key) {
		store(key: key, value: .string(value))
	}
	func encode(_ value: Int, forKey key: Key) {
		store(key: key, value: .signedInteger(Int64(value)))
	}
	func encode(_ value: Int8, forKey key: Key) {
		store(key: key, value: .signedInteger(Int64(value)))
	}
	func encode(_ value: Int16, forKey key: Key) {
		store(key: key, value: .signedInteger(Int64(value)))
	}
	func encode(_ value: Int32, forKey key: Key) {
		store(key: key, value: .signedInteger(Int64(value)))
	}
	func encode(_ value: Int64, forKey key: Key) {
		store(key: key, value: .signedInteger(value))
	}
	func encode(_ value: UInt, forKey key: Key) {
		store(key: key, value: .unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt8, forKey key: Key) {
		store(key: key, value: .unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt16, forKey key: Key) {
		store(key: key, value: .unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt32, forKey key: Key) {
		store(key: key, value: .unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt64, forKey key: Key) {
		store(key: key, value: .unsignedInteger(value))
	}
	func encode(_ value: Float, forKey key: Key) {
		store(key: key, value: .float(Double(value)))
	}
	func encode(_ value: Double, forKey key: Key) {
		store(key: key, value: .float(value))
	}
	func encode(_ value: Bool, forKey key: Key) {
		store(key: key, value: .boolean(value))
	}
	func encodeNil(forKey key: Key) {
		store(key: key, value: .null)
	}
}

extension CustomJSONEncoder.ArrayStorage: UnkeyedEncodingContainer {
	var count: Int { store.count }

	func nestedContainer<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
		return KeyedEncodingContainer(emptyDictionaryStorage(keyedBy: type))
	}
	func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
		return emptyArrayStorage()
	}
	func superEncoder() -> Encoder {
		return emptyElementStorage()
	}

	func encode<T: Encodable>(_ value: T) throws {
		let storage = emptyElementStorage()
		if let value = value as? CustomJSONCodable {
			try value.encode(toCustomJSON: storage)
		} else {
			try value.encode(to: storage)
		}
	}

	func encode(_ value: String) {
		store(.string(value))
	}
	func encode(_ value: Int) {
		store(.signedInteger(Int64(value)))
	}
	func encode(_ value: Int8) {
		store(.signedInteger(Int64(value)))
	}
	func encode(_ value: Int16) {
		store(.signedInteger(Int64(value)))
	}
	func encode(_ value: Int32) {
		store(.signedInteger(Int64(value)))
	}
	func encode(_ value: Int64) {
		store(.signedInteger(value))
	}
	func encode(_ value: UInt) {
		store(.unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt8) {
		store(.unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt16) {
		store(.unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt32) {
		store(.unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt64) {
		store(.unsignedInteger(value))
	}
	func encode(_ value: Float) {
		store(.float(Double(value)))
	}
	func encode(_ value: Double) {
		store(.float(value))
	}
	func encode(_ value: Bool) {
		store(.boolean(value))
	}
	func encodeNil() {
		store(.null)
	}
}

extension CustomJSONEncoder.ElementStorage: SingleValueEncodingContainer {

	func encode<T: Encodable>(_ value: T) throws {
		if let value = value as? CustomJSONCodable {
			try value.encode(toCustomJSON: self)
		} else {
			try value.encode(to: self)
		}
	}

	func encode(_ value: String) {
		store(.string(value))
	}
	func encode(_ value: Int) {
		store(.signedInteger(Int64(value)))
	}
	func encode(_ value: Int8) {
		store(.signedInteger(Int64(value)))
	}
	func encode(_ value: Int16) {
		store(.signedInteger(Int64(value)))
	}
	func encode(_ value: Int32) {
		store(.signedInteger(Int64(value)))
	}
	func encode(_ value: Int64) {
		store(.signedInteger(value))
	}
	func encode(_ value: UInt) {
		store(.unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt8) {
		store(.unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt16) {
		store(.unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt32) {
		store(.unsignedInteger(UInt64(value)))
	}
	func encode(_ value: UInt64) {
		store(.unsignedInteger(value))
	}
	func encode(_ value: Float) {
		store(.float(Double(value)))
	}
	func encode(_ value: Double) {
		store(.float(value))
	}
	func encode(_ value: Bool) {
		store(.boolean(value))
	}
	func encodeNil() {
		store(.null)
	}
}

private extension CustomJSONEncoder.ElementStorage {

	func serialize() throws -> Data {

		func indent(_ data: Data) -> Data {
			let lines = data.split(separator: Character("\n").asciiValue!)
			return Data("\t".utf8) + lines.joined(separator: "\n\t".utf8)
		}
		func inlineTest(_ array: [Data]) -> Bool {
			let inlineLength = 2 + array.reduce(0) { $0 + $1.count + 2 }
			let multiline = array.contains(where: { $0.contains(Character("\n").asciiValue!) })
			return inlineLength < 40 && !multiline
		}
		func primitive(_ value: Any) throws -> Data {
			return try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
		}

		switch store {

		case .dictionary(let dictionary):
			let dictionaryData = try dictionary.store.map { entry in
				let key = try primitive(entry.key.stringValue)
				let value = try entry.value.serialize()
				return key + " : ".utf8 + value
			}
			var result = Data()
			if inlineTest(dictionaryData) {
				result += "{".utf8
				result += dictionaryData.isEmpty ? "".utf8 : " ".utf8
				result += dictionaryData.joined(separator: ", ".utf8)
				result += dictionaryData.isEmpty ? "".utf8 : " ".utf8
				result += "}".utf8
			} else {
				result += "{".utf8
				result += dictionaryData.isEmpty ? "".utf8 : "\n".utf8
				result += dictionaryData.map(indent).joined(separator: ",\n".utf8)
				result += dictionaryData.isEmpty ? "".utf8 : "\n".utf8
				result += "}".utf8
			}
			return result

		case .array(let array):
			let arrayData = try array.store.map {
				try $0.serialize()
			}
			var result = Data()
			if inlineTest(arrayData) {
				result += "[".utf8
				result += arrayData.isEmpty ? "".utf8 : " ".utf8
				result += arrayData.joined(separator: ", ".utf8)
				result += arrayData.isEmpty ? "".utf8 : " ".utf8
				result += "]".utf8
			} else {
				result += "[".utf8
				result += arrayData.isEmpty ? "".utf8 : "\n".utf8
				result += arrayData.map(indent).joined(separator: ",\n".utf8)
				result += arrayData.isEmpty ? "".utf8 : "\n".utf8
				result += "]".utf8
			}
			return result

		case .string(let string):
			return try primitive(string)
		case .signedInteger(let number):
			return try primitive(number)
		case .unsignedInteger(let number):
			return try primitive(number)
		case .float(let number):
			return try primitive(number)
		case .boolean(let value):
			return try primitive(value)
		case .null:
			return try primitive(NSNull())
		case .none:
			fatalError("unexpected empty container at coding path \(codingPath)")
		}
	}
}


/* MARK: Custom JSON Decoder */

private struct CustomJSONDecoder {

	/// Reference-typed storage box.
	///
	/// Contrary to the encoder, the decoder does not actually need the
	/// reference semantics, because the entire nested structure is initialized
	/// once from `JSONSerialization` output. However, transparent sub-typing by
	/// inheritance is used, so we keep this class-typed.
	///
	/// Conformance to different protocols depends on the `Value` type parameter:
	/// * `ElementStorage` conforms to `Decoder` and `SingleValueDecodingContainer`
	/// * `ArrayStorage` conforms to `UnkeyedDecodingContainer`
	/// * `KeyedDictionaryStorage` conforms to `KeyedDecodingContainerProtocol`
	class Storage<Value> {
		var codingPath: [any CodingKey]
		let store: Value
		init(codingPath: [any CodingKey] = [], store: Value) {
			self.codingPath = codingPath
			self.store = store
		}
	}

	/// Subclass to remember `Key` type for `KeyedDecodingContainerProtocol`
	class KeyedDictionaryStorage<Key: CodingKey>: DictionaryStorage {}

	class DictionaryStorage: Storage<Dictionary<String, ElementStorage>> {
		var missingCollectionsAsEmpty: Bool = false
		init(codingPath: [any CodingKey] = [],
		     store: [String: ElementStorage],
		     missingCollectionsAsEmpty: Bool = false) {
			super.init(codingPath: codingPath, store: store)
			self.missingCollectionsAsEmpty = missingCollectionsAsEmpty
		}
	}
	class ArrayStorage: Storage<Array<ElementStorage>> {
		var currentIndex: Int = 0
	}
	typealias ElementStorage = Storage<Element>

	enum Element {
		case missingCollectionsAsEmpty
		case dictionary(DictionaryStorage)
		case array(ArrayStorage)
		case string(String)
		case number(NSNumber)
		case null
	}

	func decode<Root: Decodable>(_ type: Root.Type, from data: Data) throws -> Root {
		let object = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
		let storage = ElementStorage(from: object)
		return try storage.decode(type)
	}
}

private extension CustomJSONDecoder.Storage {
	typealias KeyedDictionaryStorage = CustomJSONDecoder.KeyedDictionaryStorage
	typealias DictionaryStorage = CustomJSONDecoder.DictionaryStorage
	typealias ArrayStorage = CustomJSONDecoder.ArrayStorage
	typealias ElementStorage = CustomJSONDecoder.ElementStorage
	typealias Element = CustomJSONDecoder.Element
}

private extension CustomJSONDecoder.ElementStorage {

	convenience init(from object: Any) {
		switch object {

		case let dictionary as Dictionary<String, Any>:
			let converted = dictionary.mapValues { ElementStorage(from: $0) }
			let storage = DictionaryStorage(store: converted)
			self.init(store: .dictionary(storage))

		case let array as Array<Any>:
			let converted = array.map { ElementStorage(from: $0) }
			let storage = ArrayStorage(store: converted)
			self.init(store: .array(storage))

		case let string as String:
			self.init(store: .string(string))

		case let number as NSNumber:
			self.init(store: .number(number))

		case is NSNull:
			self.init(store: .null)

		default:
			fatalError("unexpected JSON object of type \(type(of: object))")
		}
	}
}

private extension CustomJSONDecoder.KeyedDictionaryStorage {
	func dictionaryStorage<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey key: Key) throws -> KeyedDictionaryStorage<NestedKey> {
		let codingPath = codingPath + [key]
		if missingCollectionsAsEmpty && store[key.stringValue] == nil {
			return KeyedDictionaryStorage<NestedKey>(codingPath: codingPath, store: [:])
		}
		if case .dictionary(let storage) = try get(key) {
			return KeyedDictionaryStorage<NestedKey>(codingPath: codingPath, store: storage.store)
		}
		throw typeMismatch(DictionaryStorage.self, forKey: key)
	}
	func arrayStorage(forKey key: Key) throws -> ArrayStorage {
		let codingPath = codingPath + [key]
		if missingCollectionsAsEmpty && store[key.stringValue] == nil {
			return ArrayStorage(codingPath: codingPath, store: [])
		}
		if case .array(let storage) = try get(key) {
			storage.codingPath = codingPath
			return storage
		}
		throw typeMismatch(ArrayStorage.self, forKey: key)
	}
	/// - Important: This accessor propagates the coding path forward and checks
	///   for key existence. All other accessors should funnel through here.
	func elementStorage(forKey key: Key) throws -> ElementStorage {
		let codingPath = codingPath + [key]
		if missingCollectionsAsEmpty && store[key.stringValue] == nil {
			return ElementStorage(codingPath: codingPath, store: .missingCollectionsAsEmpty)
		}
		if let storage = store[key.stringValue] {
			storage.codingPath = codingPath
			return storage
		}
		throw DecodingError.keyNotFound(key, .init(codingPath: codingPath,
			debugDescription: "expected key \(key.stringValue) not found"))
	}
	func get(_ key: Key) throws -> Element {
		return try elementStorage(forKey: key).store
	}
	func typeMismatch(_ type: Any.Type, forKey key: Key) -> DecodingError {
		let codingPath = codingPath + [key]
		return DecodingError.typeMismatch(type, .init(codingPath: codingPath,
			debugDescription: "type found for key: \(store[key.stringValue]!.store)"))
	}
}

private extension CustomJSONDecoder.ArrayStorage {
	typealias ArrayCodingKey = CustomJSONEncoder.ArrayStorage.ArrayCodingKey
	func nextDictionaryStorage<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDictionaryStorage<Key> {
		if case .dictionary(let storage) = try next() {
			let codingPath = codingPath + [ArrayCodingKey(intValue: currentIndex)]
			return KeyedDictionaryStorage<Key>(codingPath: codingPath, store: storage.store)
		}
		throw typeMismatch(DictionaryStorage.self)
	}
	func nextArrayStorage() throws -> ArrayStorage {
		if case .array(let storage) = try next() {
			storage.codingPath = codingPath + [ArrayCodingKey(intValue: currentIndex)]
			return storage
		}
		throw typeMismatch(ArrayStorage.self)
	}
	/// - Important: This accessor propagates the coding path forward and checks
	///   for element existence. All other accessors should funnel through here.
	func nextElementStorage() throws -> ElementStorage {
		guard !isAtEnd else {
			throw DecodingError.keyNotFound(ArrayCodingKey(intValue: currentIndex), .init(codingPath: codingPath, debugDescription: "no index \(currentIndex)"))
		}
		defer { currentIndex += 1 }
		let codingPath = codingPath + [ArrayCodingKey(intValue: currentIndex)]
		store[currentIndex].codingPath = codingPath
		return store[currentIndex]
	}
	func next() throws -> Element {
		return try nextElementStorage().store
	}
	func typeMismatch(_ type: Any.Type) -> DecodingError {
		let codingPath = codingPath + [ArrayCodingKey(intValue: currentIndex - 1)]
		return DecodingError.typeMismatch(type, .init(codingPath: codingPath,
			debugDescription: "unexpected type in JSON: \(store[currentIndex - 1].store)"))
	}
}

private extension CustomJSONDecoder.ElementStorage {
	func dictionaryStorage<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDictionaryStorage<Key> {
		if case .missingCollectionsAsEmpty = store {
			// propagate missingCollectionsAsEmpty into the dictionary
			return KeyedDictionaryStorage<Key>(codingPath: codingPath, store: [:],
			                                   missingCollectionsAsEmpty: true)
		}
		if case .dictionary(let storage) = store {
			storage.codingPath = codingPath
			return KeyedDictionaryStorage<Key>(codingPath: storage.codingPath, store: storage.store,
			                                   missingCollectionsAsEmpty: storage.missingCollectionsAsEmpty)
		}
		throw typeMismatch(DictionaryStorage.self)
	}
	func arrayStorage() throws -> ArrayStorage {
		if case .missingCollectionsAsEmpty = store {
			return ArrayStorage(codingPath: codingPath, store: [])
		}
		if case .array(let storage) = store {
			storage.codingPath = codingPath
			return storage
		}
		throw typeMismatch(ArrayStorage.self)
	}
	func typeMismatch(_ type: Any.Type) -> DecodingError {
		return DecodingError.typeMismatch(type, .init(codingPath: codingPath,
			debugDescription: "unexpected type in JSON: \(store)"))
	}
}

extension CustomJSONDecoder.Element: CustomStringConvertible {
	/// Description without the associated value for brevity of debug messages.
	var description: String {
		switch self {
		case .missingCollectionsAsEmpty: return "emptyCollection"
		case .dictionary: return "Dictionary"
		case .array: return "Array"
		case .string: return "String"
		case .number: return "NSNumber"
		case .null: return "NSNull"
		}
	}
}

extension CustomJSONDecoder.ElementStorage: Decoder {
	var userInfo: [CodingUserInfoKey: Any] { [:] }

	func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
		return KeyedDecodingContainer(try dictionaryStorage(keyedBy: type))
	}
	func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		return try arrayStorage()
	}
	func singleValueContainer() throws -> SingleValueDecodingContainer {
		return self
	}
}

extension CustomJSONDecoder.KeyedDictionaryStorage: KeyedDecodingContainerProtocol {
	var allKeys: [Key] { store.keys.map { Key(stringValue: $0)! } }
	func contains(_ key: Key) -> Bool { store.keys.contains(key.stringValue) }

	func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
		return KeyedDecodingContainer(try dictionaryStorage(keyedBy: type, forKey: key))
	}
	func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
		return try arrayStorage(forKey: key)
	}
	func superDecoder() throws -> Decoder {
		return try elementStorage(forKey: Key(stringValue: "super")!)
	}
	func superDecoder(forKey key: Key) throws -> Decoder {
		return try elementStorage(forKey: key)
	}

	func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
		let storage = try elementStorage(forKey: key)
		if let type = type as? CustomJSONCodable.Type {
			return try type.init(fromCustomJSON: storage) as! T
		} else {
			return try type.init(from: storage)
		}
	}

	func decode(_ type: String.Type, forKey key: Key) throws -> String {
		if case .string(let string) = try get(key) { return string }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
		if case .number(let number) = try get(key) { return number.intValue }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
		if case .number(let number) = try get(key) { return number.int8Value }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
		if case .number(let number) = try get(key) { return number.int16Value }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
		if case .number(let number) = try get(key) { return number.int32Value }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
		if case .number(let number) = try get(key) { return number.int64Value }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
		if case .number(let number) = try get(key) { return number.uintValue }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
		if case .number(let number) = try get(key) { return number.uint8Value }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
		if case .number(let number) = try get(key) { return number.uint16Value }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
		if case .number(let number) = try get(key) { return number.uint32Value }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
		if case .number(let number) = try get(key) { return number.uint64Value }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
		if case .number(let number) = try get(key) { return number.doubleValue }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
		if case .number(let number) = try get(key) { return number.floatValue }
		throw typeMismatch(type, forKey: key)
	}
	func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
		if case .number(let number) = try get(key) { return number.boolValue }
		throw typeMismatch(type, forKey: key)
	}
	func decodeNil(forKey key: Key) throws -> Bool {
		if case .null = try get(key) { return true }
		return false
	}
}

extension CustomJSONDecoder.ArrayStorage: UnkeyedDecodingContainer {
	var isAtEnd: Bool { currentIndex == store.endIndex }
	var count: Int? { store.count }

	func nestedContainer<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
		return KeyedDecodingContainer(try nextDictionaryStorage(keyedBy: type))
	}
	func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
		return try nextArrayStorage()
	}
	func superDecoder() throws -> Decoder {
		return try nextElementStorage()
	}

	func decode<T: Decodable>(_ type: T.Type) throws -> T {
		let storage = try nextElementStorage()
		if let type = type as? CustomJSONCodable.Type {
			return try type.init(fromCustomJSON: storage) as! T
		} else {
			return try type.init(from: storage)
		}
	}

	func decode(_ type: String.Type) throws -> String {
		if case .string(let string) = try next() { return string }
		throw typeMismatch(type)
	}
	func decode(_ type: Int.Type) throws -> Int {
		if case .number(let number) = try next() { return number.intValue }
		throw typeMismatch(type)
	}
	func decode(_ type: Int8.Type) throws -> Int8 {
		if case .number(let number) = try next() { return number.int8Value }
		throw typeMismatch(type)
	}
	func decode(_ type: Int16.Type) throws -> Int16 {
		if case .number(let number) = try next() { return number.int16Value }
		throw typeMismatch(type)
	}
	func decode(_ type: Int32.Type) throws -> Int32 {
		if case .number(let number) = try next() { return number.int32Value }
		throw typeMismatch(type)
	}
	func decode(_ type: Int64.Type) throws -> Int64 {
		if case .number(let number) = try next() { return number.int64Value }
		throw typeMismatch(type)
	}
	func decode(_ type: UInt.Type) throws -> UInt {
		if case .number(let number) = try next() { return number.uintValue }
		throw typeMismatch(type)
	}
	func decode(_ type: UInt8.Type) throws -> UInt8 {
		if case .number(let number) = try next() { return number.uint8Value }
		throw typeMismatch(type)
	}
	func decode(_ type: UInt16.Type) throws -> UInt16 {
		if case .number(let number) = try next() { return number.uint16Value }
		throw typeMismatch(type)
	}
	func decode(_ type: UInt32.Type) throws -> UInt32 {
		if case .number(let number) = try next() { return number.uint32Value }
		throw typeMismatch(type)
	}
	func decode(_ type: UInt64.Type) throws -> UInt64 {
		if case .number(let number) = try next() { return number.uint64Value }
		throw typeMismatch(type)
	}
	func decode(_ type: Double.Type) throws -> Double {
		if case .number(let number) = try next() { return number.doubleValue }
		throw typeMismatch(type)
	}
	func decode(_ type: Float.Type) throws -> Float {
		if case .number(let number) = try next() { return number.floatValue }
		throw typeMismatch(type)
	}
	func decode(_ type: Bool.Type) throws -> Bool {
		if case .number(let number) = try next() { return number.boolValue }
		throw typeMismatch(type)
	}
	func decodeNil() throws -> Bool {
		if case .null = try next() { return true }
		return false
	}
}

extension CustomJSONDecoder.ElementStorage: SingleValueDecodingContainer {

	func decode<T: Decodable>(_ type: T.Type) throws -> T {
		if let type = type as? CustomJSONCodable.Type {
			return try type.init(fromCustomJSON: self) as! T
		} else {
			return try type.init(from: self)
		}
	}

	func decode(_ type: String.Type) throws -> String {
		if case .string(let string) = store { return string }
		throw typeMismatch(type)
	}
	func decode(_ type: Int.Type) throws -> Int {
		if case .number(let number) = store { return number.intValue }
		throw typeMismatch(type)
	}
	func decode(_ type: Int8.Type) throws -> Int8 {
		if case .number(let number) = store { return number.int8Value }
		throw typeMismatch(type)
	}
	func decode(_ type: Int16.Type) throws -> Int16 {
		if case .number(let number) = store { return number.int16Value }
		throw typeMismatch(type)
	}
	func decode(_ type: Int32.Type) throws -> Int32 {
		if case .number(let number) = store { return number.int32Value }
		throw typeMismatch(type)
	}
	func decode(_ type: Int64.Type) throws -> Int64 {
		if case .number(let number) = store { return number.int64Value }
		throw typeMismatch(type)
	}
	func decode(_ type: UInt.Type) throws -> UInt {
		if case .number(let number) = store { return number.uintValue }
		throw typeMismatch(type)
	}
	func decode(_ type: UInt8.Type) throws -> UInt8 {
		if case .number(let number) = store { return number.uint8Value }
		throw typeMismatch(type)
	}
	func decode(_ type: UInt16.Type) throws -> UInt16 {
		if case .number(let number) = store { return number.uint16Value }
		throw typeMismatch(type)
	}
	func decode(_ type: UInt32.Type) throws -> UInt32 {
		if case .number(let number) = store { return number.uint32Value }
		throw typeMismatch(type)
	}
	func decode(_ type: UInt64.Type) throws -> UInt64 {
		if case .number(let number) = store { return number.uint64Value }
		throw typeMismatch(type)
	}
	func decode(_ type: Double.Type) throws -> Double {
		if case .number(let number) = store { return number.doubleValue }
		throw typeMismatch(type)
	}
	func decode(_ type: Float.Type) throws -> Float {
		if case .number(let number) = store { return number.floatValue }
		throw typeMismatch(type)
	}
	func decode(_ type: Bool.Type) throws -> Bool {
		if case .number(let number) = store { return number.boolValue }
		throw typeMismatch(type)
	}
	func decodeNil() -> Bool {
		if case .null = store { return true }
		return false
	}
}


/* MARK: Custom Coding Features */

extension Encoder {

	/// Removes empty sub-containers on an already filled encoder.
	///
	/// - SeeAlso: `CustomJSONEmptyCollectionSkipping`
	public func skipEmptyCollections() throws {
		guard let storage = self as? CustomJSONEncoder.ElementStorage else {
			throw EncodingError.invalidValue(self, .init(codingPath: codingPath,
				debugDescription: "empty collection skip requires CustomJSONEncoder"))
		}

		guard case .dictionary(let dictionary) = storage.store else {
			throw EncodingError.invalidValue(storage, .init(codingPath: storage.codingPath,
				debugDescription: "empty collection skip requires keyed container"))
		}

		// examine all key-value pairs of the last-encoded container
		dictionary.store = dictionary.store.filter {
			// skip any empty immediate sub-containers
			switch $0.value.store {
			case .dictionary(let container):
				if container.store.isEmpty { return false }
			case .array(let container):
				if container.store.isEmpty { return false }
			default:
				break
			}
			return true
		}
	}
}

extension Decoder {

	/// Enables the decoder to treat missing container-type elements as empty containers.
	///
	/// - SeeAlso: `CustomJSONEmptyCollectionSkipping`
	public func enableMissingAsEmpty() throws {
		guard let storage = self as? CustomJSONDecoder.ElementStorage else {
			throw DecodingError.typeMismatch(Self.self, .init(codingPath: codingPath,
				debugDescription: "missing-as-empty requires CustomJSONDecoder"))
		}

		// modify the stored dictionary to enable missingCollectionsAsEmpty
		guard case .dictionary(let dictionary) = storage.store else {
			throw DecodingError.typeMismatch(Self.self, .init(codingPath: storage.codingPath,
				debugDescription: "missing-as-empty requires a dictionary type"))
		}
		dictionary.missingCollectionsAsEmpty = true
	}
}

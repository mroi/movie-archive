import Foundation


/* MARK: JSON Data */

/// JSON representation and compressed file storage.
public struct JSON<Root: Codable> {
	public let data: Data

	init(_ root: Root) throws {
		let encoder = CustomJSONEncoder()
		data = try encoder.encode(root)
	}

	func decode() throws -> Root {
		// TODO: use custom JSON decoder
		let decoder = JSONDecoder()
		return try decoder.decode(Root.self, from: data)
	}
}

extension JSON {

	/// Convert the JSON data into a string with configurable indentation.
	public func string(tabsAs format: TabFormat = .tabs) -> String {
		var result = String(data: data, encoding: .utf8)!
		if case .spaces(let width) = format {
			let lines = result.split(separator: "\n")
			let spaceIndented = lines.map { line -> String in
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

// TODO: add initializer/function for reading/writing compressed files


/* MARK: Custom JSON Encoder */

/// A JSON encoder with customizable behavior.
///
/// This encoder implements the following differences compared to the standard
/// `JSONEncoder`:
/// * retain element order in dictionary collections
/// * rendering of reasonably short collections in a single line
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
		let codingPath: [CodingKey]
		var store: Value
		init(codingPath: [CodingKey], store: Value) {
			self.codingPath = codingPath
			self.store = store
		}
	}

	/// Subclass to remember `Key` type for `KeyedEncodingContainerProtocol`
	class KeyedDictionaryStorage<Key: CodingKey>: DictionaryStorage {}

	typealias DictionaryStorage = Storage<Array<(key: CodingKey, value: ElementStorage)>>
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
	func store(key: CodingKey, value storage: ElementStorage) {
		precondition(!store.map(\.key.stringValue).contains(key.stringValue), "key already present")
		store.append((key: key, value: storage))
	}
	func store(key: CodingKey, value element: Element) {
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
		try value.encode(to: storage)
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
		try value.encode(to: storage)
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
		try value.encode(to: self)
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
			let dictionaryData = try dictionary.store.map { entry -> Data in
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

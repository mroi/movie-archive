import Dispatch


/* MARK: Node Types and Properties */

/// The media tree stores the structure of menus and playable assets.
///
/// Media tree is a recursive data structure formed from nodes with associated
/// values. Some nodes contain further child nodes as payload. The goal of the
/// media tree is to formalize a simple menu structure as the common interface
/// that is created by importers and understood by exporters. Transformation
/// of the tree during import and export is performed by `Pass` instances.
public indirect enum MediaTree {

	/// A playable asset like a movie or TV show.
	case asset(AssetNode)

	/// A group of nodes presented to the user for interaction.
	case menu(MenuNode)

	/// A reference to another node in the tree.
	case link(LinkNode)

	/// A collection of media trees.
	case collection(CollectionNode)

	/// An intermediate states during transformations.
	case opaque(OpaqueNode)
}

extension MediaTree {

	/// Node type for a playable asset like a movie or TV show.
	public struct AssetNode: Identifiable {
		public let id: ID

		public var kind: Kind
		public var content: MediaRecipe
		public var successor: MediaTree?

		public init(kind: Kind, content: MediaRecipe, successor: MediaTree? = nil) {
			self.id = ID()
			self.kind = kind
			self.content = content
			self.successor = successor
		}

		/// The kind of playable asset represented by an `AssetNode`.
		public enum Kind {
			/// A feature film or short film.
			case movie
			/// An individual show of episodic content, typically a TV show.
			case episode
			/// Accompanying material like bonus content.
			case extra
		}
	}

	/// Node type for a group of nodes presented to the user for interaction.
	public struct MenuNode: Identifiable {
		public let id: ID

		public var children: [MediaTree]
		public var background: MediaRecipe

		public init(children: [MediaTree], background: MediaRecipe) {
			self.id = ID()
			self.children = children
			self.background = background
		}
	}

	/// Node type for a reference to another node in the tree.
	public struct LinkNode {
		public var target: ID
		public init(target: ID) {
			self.target = target
		}
	}

	/// Node type for a collection of media trees.
	public struct CollectionNode {
		public var children: [MediaTree]
		public init(children: [MediaTree]) {
			self.children = children
		}
	}

	/// Node type for an intermediate states during transformations.
	public struct OpaqueNode: Identifiable {
		public let id: ID

		public var payload: Any
		public var children: [MediaTree]

		public init(payload: Any, children: [MediaTree] = []) {
			self.id = ID()
			self.payload = payload
			self.children = children
		}
	}
}

extension MediaTree {

	/// Identifier for media tree nodes.
	///
	/// A new ID value is generated by atomically incrementing a counter.
	public struct ID: Equatable, Hashable {
		private let value: Int

		// TODO: change to @TaskLocal allocator
		static var allocator = Allocator()

		fileprivate init() { value = Self.allocator.next() }

		class Allocator {
			private var counter = 0
			private let lock = DispatchSemaphore(value: 1)
			fileprivate func next() -> Int {
				lock.wait()
				defer { lock.signal() }
				defer { counter += 1 }
				return counter
			}
		}
	}
}


/* MARK: Media Data Handling */

/// All information needed to create a new representation of the media asset.
public struct MediaRecipe {
	// TODO: add common properties and customization points
	// * data source
	// * video, language, and subtitle track configuration
	// * metadata dictionary [enum: String]
}

/// Obtains data for a single asset from its source.
public protocol MediaDataSource {
	// TODO: functionality to fetch data from source media
}


/* MARK: Convenience Accessors */

extension MediaTree {

	/// Convenience accessor for asset nodes.
	public var asset: AssetNode? {
		if case .asset(let node) = self { return node } else { return nil }
	}
	/// Convenience accessor for menu nodes.
	public var menu: MenuNode? {
		if case .menu(let node) = self { return node } else { return nil }
	}
	/// Convenience accessor for link nodes.
	public var link: LinkNode? {
		if case .link(let node) = self { return node } else { return nil }
	}
	/// Convenience accessor for collection nodes.
	public var collection: CollectionNode? {
		if case .collection(let node) = self { return node } else { return nil }
	}
	/// Convenience accessor for opaque nodes.
	public var opaque: OpaqueNode? {
		if case .opaque(let node) = self { return node } else { return nil }
	}

	/// Convenience modifier for asset nodes.
	mutating public func withAsset(modifier: (inout AssetNode) -> Void) {
		if case .asset(var node) = self {
			modifier(&node)
			self = .asset(node)
		}
	}
	/// Convenience modifier for menu nodes.
	mutating public func withMenu(modifier: (inout MenuNode) -> Void) {
		if case .menu(var node) = self {
			modifier(&node)
			self = .menu(node)
		}
	}
	/// Convenience modifier for link nodes.
	mutating public func withLink(modifier: (inout LinkNode) -> Void) {
		if case .link(var node) = self {
			modifier(&node)
			self = .link(node)
		}
	}
	/// Convenience modifier for collection nodes.
	mutating public func withCollection(modifier: (inout CollectionNode) -> Void) {
		if case .collection(var node) = self {
			modifier(&node)
			self = .collection(node)
		}
	}
	/// Convenience modifier for opaque nodes.
	mutating public func withOpaque(modifier: (inout OpaqueNode) -> Void) {
		if case .opaque(var node) = self {
			modifier(&node)
			self = .opaque(node)
		}
	}

	/// Modify all media tree nodes matching a predicate.
	mutating public func modifyAll(where predicate: (MediaTree) -> Bool,
	                               modifier: (inout MediaTree) -> Void) {
		if predicate(self) { modifier(&self) }
		for index in childTrees.indices {
			childTrees[index].modifyAll(where: predicate, modifier: modifier)
		}
	}
	/// Modify the first media tree node matching a predicate.
	mutating public func modifyFirst(where predicate: (MediaTree) -> Bool,
	                                 modifier: (inout MediaTree) -> Void) {
		var found = false
		modifyAll(where: { !found && predicate($0) }) {
			modifier(&$0)
			found = true
		}
	}

	/// The list of immediate child trees of the current node.
	var childTrees: [Self] {
		get {
			switch self {
			case .asset(let assetNode):
				return assetNode.successor.map { [$0] } ?? []
			case .menu(let menuNode):
				return menuNode.children
			case .link:
				return []
			case .collection(let collectionNode):
				return collectionNode.children
			case .opaque(let opaqueNode):
				return opaqueNode.children
			}
		}
		set {
			switch self {
			case .asset(var assetNode):
				assert(newValue.count <= 1)
				assetNode.successor = newValue.first
				self = .asset(assetNode)
			case .menu(var menuNode):
				menuNode.children = newValue
				self = .menu(menuNode)
			case .link:
				return
			case .collection(var collectionNode):
				collectionNode.children = newValue
				self = .collection(collectionNode)
			case .opaque(var opaqueNode):
				opaqueNode.children = newValue
				self = .opaque(opaqueNode)
			}
		}
	}
}

extension MediaTree: Sequence {
	public func makeIterator() -> Iterator { Iterator(mediaTree: self) }

	/// Depth-first iterator over the media tree nodes.
	///
	/// Adds `Sequence` conformance to `MediaTree`.
	public struct Iterator: IteratorProtocol {
		var childIterators: [Array<MediaTree>.Iterator]

		init(mediaTree: MediaTree) {
			childIterators = [[mediaTree].makeIterator()]
		}

		mutating public func next() -> MediaTree? {
			while !childIterators.isEmpty {
				if let result = childIterators.last?.next() {
					childIterators.append(result.childTrees.makeIterator())
					return result
				} else {
					childIterators.removeLast()
				}
			}
			return nil
		}
	}

	/// The number of nodes in the media tree.
	public var count: Int { self.reduce(0) { result, _ in result + 1 } }
}

private extension Array {
	/// Last array element for usage in mutating optional chains.
	var last: Element? {
		get { return self.endIndex > 0 ? self[self.endIndex - 1] : nil }
		set {
			if let newValue = newValue {
				self[self.endIndex - 1] = newValue
			} else {
				self.removeLast()
			}
		}
	}
}


/* MARK: Protocol-Typed Coding */

/// Manage coding of protocol types where nothing but `Codable` conformance is known.
///
/// We have to encode protocol-typed values like `OpaqueNode.payload`, which
/// is specified as `Any & Codable`. Such types get encoded in a nested
/// container which is keyed with their own type name. `ProtocolTypeCoding`
/// acts as the `CodingKey` for this container.
///
/// In order to decode protocol-type values from just the type name, we need to
/// know a mapping of type names to types. This needs to be registered in the
/// `knownTypes` property before calling the decoder.
private struct ProtocolTypeCoding: Equatable, Hashable, CodingKey {
	var stringValue: String
	var intValue: Int? = nil
	init?(stringValue: String) {
		self.stringValue = stringValue
	}
	init?(intValue: Int) {
		self.stringValue = String(intValue)
	}
	init(type: Encodable.Type) {
		self.stringValue = String(describing: type)
	}

	@TaskLocal
	static var knownTypes: [ProtocolTypeCoding: Codable.Type]?
}

/// Error when trying to decode a protocol-typed instance of an unknown type.
///
/// Register concrete types the decoder could encounter beforehand.
/// - SeeAlso: `ProtocolTypeCoding.knownTypes`
public struct UnknownTypeError: Error {
	public let context: DecodingError.Context
	fileprivate init(_ context: DecodingError.Context) { self.context = context }
}

private extension KeyedEncodingContainer {
	/// Encode a protocol-typed value under the given key.
	///
	/// Encoding is performed in a nested container, keyed with the type’s name.
	/// The autoclosure here is needed to prove to the Swift compiler that
	/// `value()` is a concrete type conforming to `Encodable`. Just using an
	/// `Encodable`-typed parameter would give the error that the protocol does
	/// not conform to itself.
	mutating func encode(protocolTyped value: @autoclosure () -> Encodable, forKey key: Key) throws {
		var nested = nestedContainer(keyedBy: ProtocolTypeCoding.self, forKey: key)
		try value().encode(to: &nested, forKey: ProtocolTypeCoding(type: type(of: value())))
	}
}

private extension KeyedDecodingContainer {
	/// Decode a protocol-typed value for the given key.
	///
	/// The key within a nested container is used to look up the actual type.
	/// - SeeAlso: `ProtocolTypeCoding.knownTypes`
	func decode(protocolTypedForKey key: Key) throws -> Codable {
		let nested = try nestedContainer(keyedBy: ProtocolTypeCoding.self, forKey: key)
		guard nested.allKeys.count == 1 else {
			throw DecodingError.dataCorrupted(
				.init(codingPath: nested.codingPath,
					  debugDescription: "exactly one type key expected")
			)
		}
		let key = nested.allKeys.first!

		let type = ProtocolTypeCoding.knownTypes?[key]
		guard let type = type else {
			var codingPath = nested.codingPath
			codingPath.append(key)
			throw UnknownTypeError(
				.init(codingPath: codingPath,
					  debugDescription: "unknown type \(key.stringValue)")
			)
		}

		return try type.init(from: nested, forKey: key)
	}
}

private extension Encodable {
	/// Encode a protocol-typed `Encodable` into the given keyed container.
	///
	/// In Swift, protocols (including `Encodable`) do not conform to
	/// themselves. Therefore, simply calling `container.encode(_:)` with an
	/// `Encodable` protocol type does not work.
	///
	/// [This workaround](https://forums.swift.org/t/how-to-encode-objects-of-unknown-type/12253/5)
	/// exploits the fact that existentials (protocol-typed values) are “opened”
	/// when you call a method on them, which gives the extension implementation
	/// access to the underlying concrete type, which can then be used to
	/// satisfy the `Encodable` requirement for `container.encode(_:)`.
	///
	/// - ToDo: Revisit the workaround when protocol self-conformance improves.
	func encode<K>(to container: inout KeyedEncodingContainer<K>, forKey key: K) throws {
		try container.encode(self, forKey: key)
	}
}

private extension Decodable {
	/// Decode a protocol-typed `Decodable` from the given keyed container.
	init<K>(from container: KeyedDecodingContainer<K>, forKey key: K) throws {
		self = try container.decode(Self.self, forKey: key)
	}
}

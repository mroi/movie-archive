import Foundation


/* MARK: Node Types and Properties */

/// The media tree stores the structure of menus and playable assets.
///
/// Media tree is a recursive data structure formed from nodes with associated
/// values. Some nodes contain further child nodes as payload. The goal of the
/// media tree is to formalize a simple menu structure as the common interface
/// that is created by importers and understood by exporters. Transformation
/// of the tree during import and export is performed by `Pass` instances.
public indirect enum MediaTree: Codable, Sendable {

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

	/// A canonical JSON representation of the media tree.
	public func json() throws -> JSON<MediaTree> {
		try JSON(self)
	}
}

extension JSON<MediaTree> {

	/// Convert the JSON data into a `MediaTree`.
	/// - Parameter types: The JSON data can contain instances of protocol-typed
	///   properties. When decoding, the concrete types need to be known or
	///   decoding will fail. Pass types potentially occurring in the data here.
	public func mediaTree(withTypes types: [(Codable & Sendable).Type] = []) throws -> MediaTree {
		let typeKeys = types.map(ProtocolTypeCoding.init)
		let typeDictionary = Dictionary(zip(typeKeys, types), uniquingKeysWith: {
			(first, _) in first
		})
		// register types before decoding
		return try ProtocolTypeCoding.$knownTypes.withValue(typeDictionary) {
			try decode()
		}
	}
}

extension MediaTree {

	/// Node type for a playable asset like a movie or TV show.
	public struct AssetNode: Identifiable, Codable, Sendable {
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
		public enum Kind: Codable, Sendable {
			/// A feature film or short film.
			case movie
			/// An individual show of episodic content, typically a TV show.
			case episode
			/// Accompanying material like bonus content.
			case extra
		}
	}

	/// Node type for a group of nodes presented to the user for interaction.
	public struct MenuNode: Identifiable, Codable, Sendable {
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
	public struct LinkNode: Codable, Sendable {
		public var target: ID
		public init(target: ID) {
			self.target = target
		}
	}

	/// Node type for a collection of media trees.
	public struct CollectionNode: Codable, Sendable {
		public var children: [MediaTree]
		public init(children: [MediaTree]) {
			self.children = children
		}
	}

	/// Node type for an intermediate states during transformations.
	public struct OpaqueNode: Identifiable, Codable, Sendable {
		public let id: ID

		public var payload: any Codable & Sendable
		public var children: [MediaTree]

		public init(payload: any Codable & Sendable, children: [MediaTree] = []) {
			self.id = ID()
			self.payload = payload
			self.children = children
		}
	}
}

extension MediaTree {

	/// Identifier for media tree nodes.
	///
	/// A new ID value is generated by atomically incrementing a counter. Each
	/// transform starts counting from zero to obtain reproducible values.
	public struct ID: Equatable, Hashable, Codable, Sendable {
		private let value: Int

		@TaskLocal
		static var allocator = Allocator()

		fileprivate init() { value = Self.allocator.next() }

		class Allocator: @unchecked Sendable {
			private var counter = 0
			private let mutex = NSLock()
			fileprivate func next() -> Int {
				mutex.lock()
				defer { mutex.unlock() }
				defer { counter += 1 }
				return counter
			}
			/// Ensure a minimum value when node IDs are generated by decoding.
			fileprivate func raise(ifLessThan lowerBound: Int) {
				mutex.lock()
				defer { mutex.unlock() }
				if counter < lowerBound { counter = lowerBound }
			}
		}
	}
}


/* MARK: Media Data Handling */

/// All information needed to create a new representation of the media asset.
///
/// The properties `video`, `audio`, and `subtitles` list the tracks to be
/// included in the new media representation. The `stop` time is non-inclusive,
/// the indicated frame will not be part of the new representation.
public struct MediaRecipe: Codable, Sendable {

	/// The data stream containing encoded source video, audio, and subtitles.
	public var data: any MediaDataSource

	public var start: Time
	public var stop: Time

	public var video: [TrackIdentifier<Video>: Video]
	public var audio: [TrackIdentifier<Audio>: Audio]
	public var subtitles: [TrackIdentifier<Subtitles>: Subtitles]

	public var chapters: [Time: String]
	public var metadata: [Metadata]

	public init(data: any MediaDataSource,
	            start: Time = .seconds(0),
	            stop: Time = .seconds(.infinity),
	            video: [TrackIdentifier<Video>: Video] = [:],
	            audio: [TrackIdentifier<Audio>: Audio] = [:],
	            subtitles: [TrackIdentifier<Subtitles>: Subtitles] = [:],
	            chapters: [Time: String] = [:],
	            metadata: [Metadata] = []) {
		self.data = data
		self.start = start
		self.stop = stop
		self.video = video
		self.audio = audio
		self.subtitles = subtitles
		self.chapters = chapters
		self.metadata = metadata
	}

	/// A point in time relative to the beginning of this media asset.
	public enum Time: Hashable, Codable, Sendable {
		case seconds(Double)
		case frames(Int)
	}

	/// Numerical or string identifier for media track carrying audio, video, or subtitles.
	public struct TrackIdentifier<Element>: Codable, Hashable, Sendable, ExpressibleByIntegerLiteral, ExpressibleByStringLiteral {
		public let intValue: Int?
		public let stringValue: String

		static public var single: Self { Self(0) }

		public init(_ value: Int) {
			self.intValue = value
			self.stringValue = String(value)
		}
		public init(_ value: String) {
			self.intValue = Int(value)
			self.stringValue = value
		}
		public init(integerLiteral: IntegerLiteralType) {
			self.init(integerLiteral)
		}
		public init(stringLiteral: StringLiteralType) {
			self.init(stringLiteral)
		}
	}

	/// Configuration for a video track.
	public struct Video: Codable, Sendable {
		public let pixelAspect: Double?
		public let colorSpace: ColorSpace?
		public let interlace: InterlaceState?
		public let crop: Cropping?

		public let language: Locale?
		public let content: ContentInfo

		public init(pixelAspect: Double? = nil,
		            colorSpace: ColorSpace? = nil,
		            interlace: InterlaceState? = nil,
		            crop: Cropping? = nil,
		            language: Locale? = nil,
		            content: ContentInfo = .main) {
			self.pixelAspect = pixelAspect
			self.colorSpace = colorSpace
			self.interlace = interlace
			self.crop = crop
			self.language = language
			self.content = content
		}

		public struct Cropping: Codable, Sendable {
			public let top, bottom, left, right: Int
			public init(top: Int = 0, bottom: Int = 0, left: Int = 0, right: Int = 0) {
				self.top = top
				self.bottom = bottom
				self.left = left
				self.right = right
			}
		}
		public enum ColorSpace: Codable, Sendable {
			case rec601NTSC, rec601PAL, rec709, rec2020, rec2100PQ, rec2100HLG
			case sRGB, p3DCI, p3D65
		}
		public enum InterlaceState: Codable, Sendable {
			case progressive, evenFirst, oddFirst
		}
		public enum ContentInfo: Codable, Sendable {
			case main, auxiliary
		}
	}

	/// Configuration for an audio track.
	public struct Audio: Codable, Sendable {
		public let channels: [Channel]?
		public let language: Locale?
		public let content: ContentInfo

		public init(channels: [Channel]? = nil,
		            language: Locale? = nil,
		            content: ContentInfo = .main) {
			self.channels = channels
			self.language = language
			self.content = content
		}

		public enum Channel: Codable, Sendable {
			case frontLeft, frontCenter, frontRight
			case matrixSurroundLeft, matrixSurroundRight
			case frontLeftCenter, frontRightCenter
			case sideLeft, sideRight
			case backLeft, backCenter, backRight
			case lowFrequencyEffects
		}
		public enum ContentInfo: Codable, Sendable {
			case main, commentary, soundtrack, audioDescription, auxiliary
		}
	}

	/// Configuration for a subtitle track.
	public struct Subtitles: Codable, Sendable {
		public let forced: Bool
		public let language: Locale?
		public let content: ContentInfo

		public init(forced: Bool = false,
		            language: Locale? = nil,
		            content: ContentInfo = .main) {
			self.forced = forced
			self.language = language
			self.content = content
		}

		public enum ContentInfo: Codable, Sendable {
			case main, closedCaption, commentary, auxiliary
		}
	}

	/// An item of metadata describing the asset.
	public enum Metadata: Codable, Sendable {
		case artwork(data: Data, format: ImageFormat)
		case title(String, original: String? = nil, sortAs: String? = nil)
		case artist(String)
		case series(String, sortAs: String? = nil)
		case season(Int)
		case episode(Int, of: Int? = nil, id: String? = nil)
		case genre(Genre)
		case release(Date)
		case summary(String)
		case description(String)
		case rating(Rating)
		case studio(String)
		case cast([String])
		case directors([String])
		case producers([String])
		case writers([String])

		public enum ImageFormat: Codable, Sendable {
			case jpeg, heic, png, tiff
		}
		public enum Genre: Codable, Sendable {
			case action, comedy, drama, horror, romance, thriller
			case scienceFictionAndFantasy, kidsAndFamily
			case animation, musical, sport, western
			case documentary, independent, shorts
		}
		public enum Rating: Codable, Sendable {
			case unrated, unrestricted
			case age(Int), parentalGuidance
		}
	}
}

/// Obtains data for a single asset from its source.
public protocol MediaDataSource: Codable, Sendable {
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
			if let newValue {
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
/// is specified as `any Codable & Sendable`. Such types get encoded in a nested
/// container which is keyed with their own type name. `ProtocolTypeCoding`
/// acts as the `CodingKey` for this container.
///
/// In order to decode protocol-type values from just the type name, we need to
/// know a mapping of type names to types. This needs to be registered in the
/// `knownTypes` property before calling the decoder.
private struct ProtocolTypeCoding: Equatable, Hashable, CodingKey {
	var stringValue: String
	var intValue: Int? = nil
	init(stringValue: String) {
		self.stringValue = stringValue
	}
	init(intValue: Int) {
		self.stringValue = String(intValue)
	}
	init(type: Encodable.Type) {
		self.stringValue = String(describing: type)
	}

	@TaskLocal
	static var knownTypes: [ProtocolTypeCoding: any (Codable & Sendable).Type]?
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
	mutating func encode(protocolTyped value: any Encodable, forKey key: Key) throws {
		var nested = nestedContainer(keyedBy: ProtocolTypeCoding.self, forKey: key)
		try nested.encode(value, forKey: ProtocolTypeCoding(type: type(of: value)))
	}
}

private extension KeyedDecodingContainer {
	/// Decode a protocol-typed value for the given key.
	///
	/// The key within a nested container is used to look up the actual type.
	/// - SeeAlso: `ProtocolTypeCoding.knownTypes`
	func decode(protocolTypedForKey key: Key) throws -> any Codable & Sendable {
		let nested = try nestedContainer(keyedBy: ProtocolTypeCoding.self, forKey: key)
		let key = try nested.singleKey

		let type = ProtocolTypeCoding.knownTypes?[key]
		guard let type else {
			var codingPath = nested.codingPath
			codingPath.append(key)
			throw UnknownTypeError(
				.init(codingPath: codingPath,
					  debugDescription: "unknown type \(key.stringValue)")
			)
		}

		return try nested.decode(type, forKey: key)
	}
}


/* MARK: Custom JSON Coding */

extension MediaTree: CustomJSONCodable {
	// custom encoding: encode single associated value directly, no positional key

	public func encode(toCustomJSON encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
		case .asset(let assetNode):
			try container.encode(assetNode, forKey: .asset)
		case .menu(let menuNode):
			try container.encode(menuNode, forKey: .menu)
		case .link(let linkNode):
			try container.encode(linkNode, forKey: .link)
		case .collection(let collectionNode):
			try container.encode(collectionNode, forKey: .collection)
		case .opaque(let opaqueNode):
			try container.encode(opaqueNode, forKey: .opaque)
		}
	}

	public init(fromCustomJSON decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		switch try container.singleKey {
		case .asset:
			self = .asset(try container.decode(AssetNode.self, forKey: .asset))
		case .menu:
			self = .menu(try container.decode(MenuNode.self, forKey: .menu))
		case .link:
			self = .link(try container.decode(LinkNode.self, forKey: .link))
		case .collection:
			self = .collection(try container.decode(CollectionNode.self, forKey: .collection))
		case .opaque:
			self = .opaque(try container.decode(OpaqueNode.self, forKey: .opaque))
		}
	}
}

extension MediaTree.AssetNode.Kind: CustomJSONCompactEnum {}

extension MediaTree.CollectionNode: CustomJSONCodable {
	// custom encoding: encode children directly without key
	public func encode(toCustomJSON encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(children)
	}
	public init(fromCustomJSON decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		children = try container.decode(Array.self)
	}
}

extension MediaTree.OpaqueNode: CustomJSONEmptyCollectionSkipping {
	// custom encoding needed because of existentially typed member
	private enum CodingKeys: String, CodingKey {
		case id, payload, children
	}
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encode(protocolTyped: payload, forKey: .payload)
		try container.encode(children, forKey: .children)
	}
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(ID.self, forKey: .id)
		payload = try container.decode(protocolTypedForKey: .payload)
		children = try container.decode(Array.self, forKey: .children)
	}
}

extension MediaTree.ID: CustomJSONCodable {
	// custom encoding: encode ID value directly
	public func encode(toCustomJSON encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(value)
	}
	public init(fromCustomJSON decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		value = try container.decode(Int.self)
		if value > Int.max / 2 {
			throw DecodingError.dataCorruptedError(in: container,
				debugDescription: "unreasonably large node ID: \(value)")
		}
		Self.allocator.raise(ifLessThan: value)
	}
}

extension MediaRecipe {
	// custom encoding needed because of any MediaDataSource typed member
	private enum CodingKeys: String, CodingKey {
		case data, start, stop, video, audio, subtitles, chapters, metadata
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(protocolTyped: data, forKey: .data)
		try container.encode(start, forKey: .start)
		try container.encode(stop, forKey: .stop)
		try container.encode(video, forKey: .video)
		try container.encode(audio, forKey: .audio)
		try container.encode(subtitles, forKey: .subtitles)
		try container.encode(chapters, forKey: .chapters)
		try container.encode(metadata, forKey: .metadata)
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let typeErasedData = try container.decode(protocolTypedForKey: .data)
		guard let dataSource = typeErasedData as? MediaDataSource else {
			throw DecodingError.typeMismatch(MediaDataSource.self,
				.init(codingPath: decoder.codingPath, debugDescription:
					"value of type \(MediaDataSource.self) expected"))
		}
		data = dataSource
		start = try container.decode(Time.self, forKey: .start)
		stop = try container.decode(Time.self, forKey: .stop)
		video = try container.decode([TrackIdentifier<Video>: Video].self, forKey: .video)
		audio = try container.decode([TrackIdentifier<Audio>: Audio].self, forKey: .audio)
		subtitles = try container.decode([TrackIdentifier<Subtitles>: Subtitles].self, forKey: .subtitles)
		chapters = try container.decode([Time: String].self, forKey: .chapters)
		metadata = try container.decode([Metadata].self, forKey: .metadata)
	}
}

extension MediaRecipe.Time: CustomJSONStringKeyRepresentable, CustomJSONCodable {
	// custom encoding: time as human-readable string

	public var stringValue: String {
		switch self {
		case .seconds(.infinity):
			return "∞"
		case .seconds(let totalSeconds):
			let totalSeconds = totalSeconds + 0.0005  // round to milliseconds
			let (hours, hoursRemainder) = Int(totalSeconds).quotientAndRemainder(dividingBy: 60 * 60)
			let (minutes, seconds) = hoursRemainder.quotientAndRemainder(dividingBy: 60)
			let milliseconds = Int(totalSeconds.truncatingRemainder(dividingBy: 1) * 1000)
			var string: String
			if hours != 0 || minutes != 0 {
				if hours != 0 {
					string = String(hours) + ":" + String(format: "%02d", minutes)
				} else {
					string = String(minutes)
				}
				string += ":" + String(format: "%02d", seconds)
			} else {
				string = String(seconds)
			}
			return string + "." + String(format: "%03d", milliseconds)
		case .frames(let frames):
			return String(frames)
		}
	}

	/// - ToDo: Simplify using `Regex` once we move to macOS 13
	public init?(stringValue: String) {
		switch stringValue {
		case "∞": self = .seconds(.infinity)
		case let string where string.contains("."):
			let substrings = string.split(separator: ":")
			guard 0...3 ~= substrings.count else { return nil }
			var components: [Double] = []
			for string in substrings.reversed() {
				guard let number = Double(string) else { return nil }
				components.append(number)
			}
			let hours = components.count > 2 ? components[2] * 60 * 60 : 0
			let minutes = components.count > 1 ? components[1] * 60 : 0
			let seconds = components[0]
			self = .seconds(hours + minutes + seconds)
		default:
			guard let frames = Int(stringValue) else { return nil }
			self = .frames(frames)
		}
	}
}

extension MediaRecipe.TrackIdentifier: CustomJSONStringKeyRepresentable {
	public static func < (lhs: Self, rhs: Self) -> Bool {
		if let lhs = lhs.intValue, let rhs = rhs.intValue {
			return lhs < rhs
		} else {
			return lhs.stringValue < rhs.stringValue
		}
	}
	public init(stringValue: String) { self.init(stringValue) }
}

extension MediaRecipe.Video.ColorSpace: CustomJSONCompactEnum {}
extension MediaRecipe.Video.InterlaceState: CustomJSONCompactEnum {}
extension MediaRecipe.Video.ContentInfo: CustomJSONCompactEnum {}
extension MediaRecipe.Audio.Channel: CustomJSONCompactEnum {}
extension MediaRecipe.Audio.ContentInfo: CustomJSONCompactEnum {}
extension MediaRecipe.Subtitles.ContentInfo: CustomJSONCompactEnum {}
extension MediaRecipe.Metadata.ImageFormat: CustomJSONCompactEnum {}
extension MediaRecipe.Metadata.Genre: CustomJSONCompactEnum {}
extension MediaRecipe.Metadata.Rating: CustomJSONCompactEnum {}

extension MediaRecipe.Metadata: CustomJSONCodable {
	public func encode(toCustomJSON encoder: Encoder) throws {
		switch self {
		case .rating(let rating):
			var container = encoder.container(keyedBy: EnumKeys.self)
			try container.encode(rating, forKey: "rating")
		case .cast(let cast):
			var container = encoder.container(keyedBy: EnumKeys.self)
			try container.encode(cast, forKey: "cast")
		case .directors(let directors):
			var container = encoder.container(keyedBy: EnumKeys.self)
			try container.encode(directors, forKey: "directors")
		case .producers(let producers):
			var container = encoder.container(keyedBy: EnumKeys.self)
			try container.encode(producers, forKey: "producers")
		case .writers(let writers):
			var container = encoder.container(keyedBy: EnumKeys.self)
			try container.encode(writers, forKey: "writers")
		default:
			try encode(to: encoder)
			try encoder.compactifyEnum()
		}
	}

	public init(fromCustomJSON decoder: Decoder) throws {
		let container = try? decoder.container(keyedBy: EnumKeys.self)
		let label = try? container?.singleKey.stringValue
		switch label {
		case "rating":
			self = .rating(try container!.decode(Rating.self))
		case "cast":
			self = .cast(try container!.decode([String].self))
		case "directors":
			self = .directors(try container!.decode([String].self))
		case "producers":
			self = .producers(try container!.decode([String].self))
		case "writers":
			self = .writers(try container!.decode([String].self))
		default: try self.init(from: decoder.reconstructedEnum())
		}
	}
}

extension Locale: CustomJSONCodable {
	public func encode(toCustomJSON encoder: Encoder) throws {
		try identifier.encode(to: encoder)
	}
	public init(fromCustomJSON decoder: Decoder) throws {
		let identifier = try String(from: decoder)
		self = Locale(identifier: identifier)
	}
}

extension Date: CustomJSONCodable {
	public func encode(toCustomJSON encoder: Encoder) throws {
		try ISO8601Format().encode(to: encoder)
	}
	public init(fromCustomJSON decoder: Decoder) throws {
		let iso8601Date = try String(from: decoder)
		self = try Date.ISO8601FormatStyle().parse(iso8601Date)
	}
}

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
	public struct AssetNode {
		public var kind: Kind
		public var content: MediaRecipe
		public var successor: MediaTree?

		public init(kind: Kind, content: MediaRecipe, successor: MediaTree? = nil) {
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
	public struct MenuNode {
		public var children: [MediaTree]
		public var background: MediaRecipe

		public init(children: [MediaTree], background: MediaRecipe) {
			self.children = children
			self.background = background
		}
	}

	/// Node type for a reference to another node in the tree.
	public struct LinkNode {
		public init() {
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
	public struct OpaqueNode {
		public var payload: Any
		public var children: [MediaTree]

		public init(payload: Any, children: [MediaTree] = []) {
			self.payload = payload
			self.children = children
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
}

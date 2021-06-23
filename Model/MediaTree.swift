/// The media tree stores the structure of menus and playable assets.
///
/// Media tree is a recursive data structure formed from nodes with associated
/// values. Some nodes contain further child nodes as payload. The goal of the
/// media tree is to formalize a simple menu structure as the common interface
/// that is created by importers and understood by exporters. Transformation
/// of the tree during import and export is performed by `Pass` instances.
public enum MediaTree {

	/// A playable asset like a movie or TV show.
	case asset

	/// A collection of child nodes presented to the user.
	case menu

	/// An unowned reference to another node in the tree.
	case link

	/// Storage for intermediate states during transformations.
	case opaque
}

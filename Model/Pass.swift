import Foundation


/// Operator to manipulate a `MediaTree`.
///
/// A `Pass` takes a `MediaTree` as input and outputs a new one. It represents
/// a single step of a tree transformation. Passes can be combined into larger
/// operations recursively:
/// * A pass can invoke itself recursively on child trees.
/// * A pass can invoke a chain of sub-passes on the tree.
public protocol Pass {
}


/// A special pass that receives no input.
public protocol ImportPass {

	/// Creates an appropriate importer if the source is supported.
	init(source url: URL) throws

	/// Generates an initial `MediaTree` without receiving any input.
	func generate() throws -> MediaTree
}

/// A special pass that generates no output other than side effects.
public protocol ExportPass {

	/// Receives a `MediaTree` without returning a new one.
	func consume(_ mediaTree: MediaTree) throws
}

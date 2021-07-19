import Foundation


/// Operator to manipulate a `MediaTree`.
///
/// A `Pass` takes a `MediaTree` as input and outputs a new one. It represents
/// a single step of a tree transformation. Passes are combined into larger
/// operations recursively:
/// * A pass can invoke itself recursively on child trees.
/// * A pass can invoke a chain of sub-passes on the tree.
public protocol Pass {

	/// The sub-passes invoked as part of the execution of this `Pass`.
	var subPasses: [Pass] { get }
}


/// A special pass that receives no input.
public protocol ImportPass: Pass {

	/// Creates an appropriate importer if the source is supported.
	init(source url: URL) throws
}

/// A special pass that generates no output other than side effects.
public protocol ExportPass: Pass {}


/* MARK: Default Implementations */

public extension Pass {
	var subPasses: [Pass] { get { [] } }
}

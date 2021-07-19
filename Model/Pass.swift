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

	/// Have the pass process a `MediaTree`.
	///
	/// The default implementation checks if sub-passes are configured via
	/// the `subPasses` property. If so, the media tree is processed by
	/// iteratively invoking all those sub-passes. Otherwise, the pass itself
	/// is asked to recursively process the media tree.
	///
	/// - Note: Concrete passes can implement their specific behavior by
	///   replacing the default implementations of one or multiple `process`
	///   functions.
	func process(_ mediaTree: MediaTree) -> MediaTree

	/// Have all sub-passes process the `MediaTree`.
	///
	/// - Note: Not meant to be called from the outside, but to be implemented
	///   by concrete passes.
	func process(bySubPasses mediaTree: MediaTree) -> MediaTree

	/// Have the pass recurse over a `MediaTree`.
	///
	/// Recursion is depth-first. The default implementation processes the
	/// current node before performing recursion to the child nodes.
	///
	/// - Note: Not meant to be called from the outside, but to be implemented
	///   by concrete passes.
	func process(byTreeRecursion mediaTree: MediaTree) -> MediaTree

	/// Have the pass process a single `MediaTree` node.
	///
	/// - Note: Not meant to be called from the outside, but to be implemented
	///   by concrete passes.
	func process(singleNode mediaTree: MediaTree) -> MediaTree
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

	func process(_ mediaTree: MediaTree) -> MediaTree {
		if subPasses.isEmpty {
			return process(byTreeRecursion: mediaTree)
		} else {
			return process(bySubPasses: mediaTree)
		}
	}

	func process(bySubPasses mediaTree: MediaTree) -> MediaTree {
		return subPasses.reduce(mediaTree) { $1.process($0) }
	}

	func process(byTreeRecursion mediaTree: MediaTree) -> MediaTree {
		var node = process(singleNode: mediaTree)
		node.childTrees = node.childTrees.map {
			process(byTreeRecursion: $0)
		}
		return node
	}

	func process(singleNode mediaTree: MediaTree) -> MediaTree {
		return mediaTree
	}
}

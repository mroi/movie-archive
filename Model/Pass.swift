import Foundation


/* MARK: Pass Protocols */

/// Operator to manipulate a `MediaTree`.
///
/// A `Pass` takes a `MediaTree` as input and outputs a new one. It represents
/// a single step of a tree transformation. Passes can be combined into larger
/// operations recursively:
/// * A pass can invoke a chain of sub-passes on the tree.
///
/// To get a helpful default implementation of those recursions, a pass can
/// adopt the `SubPassRecursing` protocol. Specific pass behavior is introduced
/// by selectively replacing the default implementation.
///
/// - SeeAlso: `SubPassRecursing`, `ImportPass`, `ExportPass`
public protocol Pass: AnyPass {

	/// Ask the pass to process a `MediaTree`.
	mutating func process(_ mediaTree: MediaTree) throws -> MediaTree
}

/// Manipulate a `MediaTree` by sub-pass recursion.
///
/// The default implementation iteratively processes the media tree by invoking
/// all sub-passes in array order.
public protocol SubPassRecursing {

	/// The sub-passes invoked as part of the execution of this pass.
	var subPasses: [Pass] { get }

	/// Have all sub-passes process the `MediaTree`.
	///
	/// - Important: Replacing the default implementation is not recommended,
	/// because it performs logging and cancellation for the executed sub-passes.
	mutating func process(bySubPasses mediaTree: MediaTree) throws -> MediaTree
}

/// A special pass that receives no input.
public protocol ImportPass: AnyPass {

	/// Creates an appropriate importer if the source is supported.
	init(source url: URL) throws

	/// Generates an initial `MediaTree` without receiving any input.
	func generate() throws -> MediaTree
}

/// A special pass that generates no output other than side effects.
public protocol ExportPass: AnyPass {

	/// Receives a `MediaTree` without returning a new one.
	func consume(_ mediaTree: MediaTree) throws
}

/// A `Pass`, `ImportPass`, or `ExportPass`.
///
/// Consumers of the passes API should rarely need this. It is used internally
/// to offer protocol extensions and default implementations for all passes.
public protocol AnyPass: CustomStringConvertible {}


/* MARK: Default Implementations */

extension AnyPass {
	public var description: String { String(describing: type(of: self)) }
}

extension AnyPass {
	/// Wraps pass execution with generic logging and cancellation implementations.
	///
	/// Invocations of `process()`, `generate()`, and `consume()` should be
	/// wrapped by this function.
	///
	/// - ToDo: Reconsider this design whenever function wrappers are added to Swift.
	func run<Result>(_ body: () throws -> Result) rethrows -> Result {
		// TODO: cancellation check

		Transform.subject.send(.message(level: .debug, "starting \(self.description)"))
		let result = try body()
		Transform.subject.send(.message(level: .debug, "finished \(self.description)"))

		return result
	}
}

public extension Pass where Self: SubPassRecursing {
	func process(_ mediaTree: MediaTree) throws -> MediaTree {
		return try process(bySubPasses: mediaTree)
	}
}

public extension SubPassRecursing {
	func process(bySubPasses mediaTree: MediaTree) throws -> MediaTree {
		var result = mediaTree
		for var pass in subPasses {
			result = try pass.run { try pass.process(result) }
		}
		return result
	}
}

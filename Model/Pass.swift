import Foundation


/// Operator to manipulate a `MediaTree`.
///
/// A `Pass` takes a `MediaTree` as input and outputs a new one. It represents
/// a single step of a tree transformation. Passes can be combined into larger
/// operations recursively:
/// * A pass can invoke itself recursively on child trees.
/// * A pass can invoke a chain of sub-passes on the tree.
public protocol Pass: AnyPass {
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

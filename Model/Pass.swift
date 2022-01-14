import Foundation


/* MARK: Pass Protocols */

/// Operator to manipulate a `MediaTree`.
///
/// A `Pass` takes a `MediaTree` as input and outputs a new one. It represents
/// a single step of a tree transformation. Passes can be combined into larger
/// operations recursively:
/// * A pass can invoke a chain of sub-passes on the tree.
/// * A pass can invoke itself recursively on child trees.
///
///
/// To get helpful default implementations of these recursions, a pass can
/// adopt the `SubPassRecursing` or `TreeRecursing` protocols. Specific pass
/// behavior is introduced by selectively replacing the default implementations.
///
/// - SeeAlso: `SubPassRecursing`, `TreeRecursing`, `ImportPass`, `ExportPass`
public protocol Pass: AnyPass {

	/// Ask the pass to process a `MediaTree`.
	mutating func process(_ mediaTree: MediaTree) async throws -> MediaTree
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
	mutating func process(bySubPasses mediaTree: MediaTree) async throws -> MediaTree
}

/// Manipulate a `MediaTree` by tree recursion.
///
/// The default implementation recursively traverses the media tree and invokes
/// `process(singleNode:)` on each node.
public protocol TreeRecursing {

	/// Have the pass recurse over a `MediaTree`.
	///
	/// Recursion is depth-first. The default implementation processes the
	/// current node before performing recursion to the child nodes.
	mutating func process(byTreeRecursion mediaTree: MediaTree) async throws -> MediaTree

	/// Have the pass process a single `MediaTree` node.
	mutating func process(singleNode mediaTree: MediaTree) async throws -> MediaTree
}

/// A special pass that receives no input.
public protocol ImportPass: AnyPass {

	/// Creates an appropriate importer if the source is supported.
	init(source url: URL) async throws

	/// Creates an appropriate importer if the source is supported.
	/// - Remark: The synchronous variant only remains for Playgrounds
	///   compatibility.
	init(source url: URL) throws

	/// Generates an initial `MediaTree` without receiving any input.
	func generate() async throws -> MediaTree
}

/// A special pass that generates no output other than side effects.
public protocol ExportPass: AnyPass {

	/// Receives a `MediaTree` without returning a new one.
	func consume(_ mediaTree: MediaTree) async throws
}

/// A `Pass`, `ImportPass`, or `ExportPass`.
///
/// Consumers of the passes API should rarely need this. It is used internally
/// to offer protocol extensions and default implementations for all passes.
public protocol AnyPass: CustomStringConvertible {}


/* MARK: Sub-Pass Builder */

/// A result builder for an array of sub-passes
@resultBuilder
public enum SubPassBuilder {
	public static func buildExpression(_ element: Pass) -> [Pass] { [element] }
	public static func buildOptional(_ maybe: [Pass]?) -> [Pass] { maybe ?? [] }
	public static func buildEither(first: [Pass]) -> [Pass] { first }
	public static func buildEither(second: [Pass]) -> [Pass] { second }
	public static func buildBlock(_ passes: [Pass]...) -> [Pass] {
		Array(passes.joined())
	}
	public static func buildArray(_ iterations: [[Pass]]) -> [Pass] {
		Array(iterations.joined())
	}
}

/// A namespace for pass types that help compose larger pass graphs.
public enum Base {}


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
	func run<Result>(_ body: () async throws -> Result) async throws -> Result {
		await Task.yield()
		if await Transform.state == .error { withUnsafeCurrentTask { $0?.cancel() } }
		try Task.checkCancellation()

		Transform.subject.send(.message(level: .debug, "starting \(self.description)"))
		let result = try await body()
		Transform.subject.send(.message(level: .debug, "finished \(self.description)"))

		await Task.yield()
		if await Transform.state == .error { withUnsafeCurrentTask { $0?.cancel() } }
		try Task.checkCancellation()

		return result
	}
}

public extension Pass where Self: SubPassRecursing {
	func process(_ mediaTree: MediaTree) async throws -> MediaTree {
		return try await process(bySubPasses: mediaTree)
	}
}

public extension Pass where Self: TreeRecursing {
	mutating func process(_ mediaTree: MediaTree) async throws -> MediaTree {
		return try await process(byTreeRecursion: mediaTree)
	}
}

public extension SubPassRecursing {
	func process(bySubPasses mediaTree: MediaTree) async throws -> MediaTree {
		var result = mediaTree
		for var pass in subPasses {
			result = try await pass.run { try await pass.process(result) }
		}
		return result
	}
}

public extension TreeRecursing {
	mutating func process(byTreeRecursion mediaTree: MediaTree) async throws -> MediaTree {
		var result = try await process(singleNode: mediaTree)
		let childTrees = result.childTrees
		result.childTrees = Array()
		result.childTrees.reserveCapacity(childTrees.count)
		for childTree in childTrees {
			result.childTrees.append(try await process(byTreeRecursion: childTree))
		}
		return result
	}
}

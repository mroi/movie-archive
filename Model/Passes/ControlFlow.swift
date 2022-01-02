extension Base {

	/// A pass which loops over all its sub-passes repeatedly.
	///
	/// The loop continues as long as one sub-pass reports `true` as its loop
	/// condition. If none of the sub-passes conform to `ConditionFlag`, no
	/// iterations are performed.
	public struct Loop: Pass, SubPassRecursing {
		public var subPasses: [Pass]

		public init(@SubPassBuilder _ builder: () -> [Pass]) {
			subPasses = builder()
		}

		public mutating func process(_ mediaTree: MediaTree) throws -> MediaTree {
			var result = mediaTree
			while subPasses.contains(where: { ($0 as? ConditionFlag)?.condition == true }) {
				for (index, pass) in subPasses.enumerated() {
					result = try pass.run {
						// mutate sub-pass state in-place so it survives iterations
						try subPasses[index].process(result)
					}
				}
			}
			return result
		}
	}
}

/// Conforming passes expose a boolean condition flag.
public protocol ConditionFlag {

	/// The indicated boolean condition.
	var condition: Bool { get }
}

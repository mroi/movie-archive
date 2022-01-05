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

	/// A pass which conditionally executes sub-passes.
	///
	/// The condition is given by a closure or a `ConditionFlag` pass. The `If` pass itself
	/// exposes this condition to the outside by itself conforming to `ConditionFlag`.
	public struct If: Pass, SubPassRecursing, ConditionFlag {
		private var conditionPass: Pass & ConditionFlag
		public var condition: Bool { conditionPass.condition }
		public var subPasses: [Pass]

		public init(_ condition: Pass & ConditionFlag, @SubPassBuilder _ builder: () -> [Pass]) {
			conditionPass = condition
			subPasses = builder()
		}
		public init(_ condition: @escaping (MediaTree) -> Bool, @SubPassBuilder _ builder: () -> [Pass]) {
			struct ConditionPass: Pass, ConditionFlag {
				var condition: Bool = true
				let body: (MediaTree) -> Bool
				mutating func process(_ mediaTree: MediaTree) -> MediaTree {
					condition = body(mediaTree)
					return mediaTree
				}
			}
			conditionPass = ConditionPass(body: condition)
			subPasses = builder()
		}

		public mutating func process(_ mediaTree: MediaTree) throws -> MediaTree {
			var result = try conditionPass.run {
				try conditionPass.process(mediaTree)
			}
			if conditionPass.condition {
				result = try process(bySubPasses: mediaTree)
			}
			return result
		}
	}

	/// A pass which repeatedly executes sub-passes while a condition remains true.
	///
	/// The condition is given by a closure or a `ConditionFlag` pass.
	public struct While: Pass {
		private var ifPass: Pass & ConditionFlag

		public init(_ condition: Pass & ConditionFlag, @SubPassBuilder _ builder: () -> [Pass]) {
			ifPass = If(condition, builder)
		}
		public init(_ condition: @escaping (MediaTree) -> Bool, @SubPassBuilder _ builder: () -> [Pass]) {
			ifPass = If(condition, builder)
		}

		public mutating func process(_ mediaTree: MediaTree) throws -> MediaTree {
			var result = mediaTree
			while ifPass.condition {
				// invoke internal pass without ifPass.run so it does not log itself
				result = try ifPass.process(mediaTree)
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

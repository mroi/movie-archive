import Foundation
import Combine
import SwiftUI
import PlaygroundSupport
import MovieArchiveModel


/* MARK: Updates Subscriber */

/// Synchronously obtain `Transform` status updates in a Playground.
///
/// Subscribe an instance to a transform publisher and call `next()` repeatedly
/// to synchronously pull individual status updates from a running transform.
public class PlaygroundTransformUpdates {
	let resultAvailable = DispatchSemaphore(value: 0)
	var result: Element?
	let resultConsumed = DispatchSemaphore(value: 0)

	public init() {
		PlaygroundPage.current.needsIndefiniteExecution = true
	}
}

extension PlaygroundTransformUpdates: Subscriber {
	public typealias Input = Transform.Publisher.Output
	public typealias Failure = Transform.Publisher.Failure

	public func receive(subscription: Subscription) {
		subscription.request(.unlimited)
	}

	/// Transform status updates arrive here.
	/// - Note: Since the calling thread is undefined, we cannot directly
	///   interact with Playground UI here. Setting the live view for example
	///   will deadlock.
	public func receive(_ input: Input) -> Subscribers.Demand {
		switch input {
		case .message:
			break
		case .progress, .mediaTree:
			result = input
			resultAvailable.signal()
			resultConsumed.wait()
		}
		return .none
	}

	public func receive(completion: Subscribers.Completion<Failure>) {
		result = nil
		resultAvailable.signal()
	}
}

extension PlaygroundTransformUpdates: IteratorProtocol {
	public typealias Element = Transform.Publisher.Output

	public func next() -> Element? {
		defer { resultConsumed.signal() }
		resultAvailable.wait()
		if result == nil { PlaygroundPage.current.finishExecution() }
		return result
	}
}

extension PlaygroundTransformUpdates: CustomStringConvertible {
	public var description: String { "TransformUpdates" }
}


/* MARK: Status Handling */

extension Transform.Status: CustomPlaygroundDisplayConvertible {
	public var playgroundDescription: Any {
		switch self {
		case .message(level: _, let stringKey):
			return String(unlocalized: stringKey)
		case .progress(let progress):
			return progress.localizedDescription ?? "Progress"
		case .mediaTree:
			return "media tree"
		}
	}
}

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

extension Transform.Status {

	/// Default handling of `Transform` status updates.
	public func handle() {
		switch self {
		case .message:
			break

		case .progress(let progress):
			let progressBar = ProgressView(progress)
				.frame(width: 250)
				.padding()
				.background()
				.padding()
			PlaygroundPage.current.setLiveView(progressBar)

		case .mediaTree(let interaction):
			interaction.finish()
		}
	}

	/// Convenience access to the media tree for `mediaTree` status cases.
	public var mediaTree: MediaTree! {
		get {
			if case .mediaTree(let interaction) = self {
				return interaction.value
			} else {
				return nil
			}
		}
		set {
			if case .mediaTree(let interaction) = self, let newValue = newValue {
				interaction.value = newValue
			}
		}
	}
}

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


/* MARK: Media Tree Visualization */

extension MediaTree {

	/// Inspect the media tree using interactive UI.
	public func show() {

		struct MirrorItem: Hashable, Identifiable {
			static var count = 0

			let id: Int = {
				defer { count += 1 }
				return count
			}()
			let label: String?
			let value: String
			let type: String
			let children: [MirrorItem]?

			init(label: String?, value: Any) {
				let mirror = Mirror(reflecting: value)
				self.label = label
				self.value = String(describing: value)
				self.type = String(describing: mirror.subjectType)
				if mirror.children.isEmpty {
					children = nil
				} else {
					children = mirror.children.map {
						MirrorItem(label: $0.label, value: $0.value)
					}
				}
			}

			func render() -> AttributedString {
				var label = self.label.map { AttributedString($0 + " = ") } ?? ""
				label.font = .body.bold()
				let value = AttributedString(self.value + " ")
				var type = AttributedString(self.type)
				type.foregroundColor = .secondaryLabelColor
				type.font = .body.italic()

				return children == nil ? label + value + type : label + type
			}
		}

		var greyText = AttributeContainer()
		greyText.foregroundColor = .secondaryLabelColor

		@State var selection: Int? = 0
		let root = MirrorItem(label: "self", value: self)
		let view = List(selection: $selection) {
			OutlineGroup(root, children: \.children) { item in
				Text(item.render())
			}
		}.frame(width: 800, height: 300).padding()
		PlaygroundPage.current.setLiveView(view)
	}
}

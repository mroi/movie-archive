import Foundation
import Combine
import os


/* MARK: Entry Point for Clients */

/// An end-to-end `MediaTree` transformation, combining one importer and one exporter `Pass`.
///
/// The `Transform` executes exactly two passes on an initially empty `MediaTree`:
/// An importer generates a media tree representation from an imported source.
/// An exporter serializes the media tree to a persistent format.
///
/// Execution of the transform via `execute()` is a long-running operation.
/// The `publisher` allows the caller to receive status updates asynchronously
/// while the transform is ongoing. You should subscribe to the `publisher`
/// before invoking `execute()`. Such updates can include points of interaction
/// that applications should offer to users.
///
/// - Remark: Typical clients use a `Transform` together with an appropriate
///   importer and exporter as the entry point into model functionality.
public actor Transform {

	let importer: ImportPass
	let exporter: ExportPass

	let subject = Subject(logging: true)
	var state = State.initial

	/// Internal state of the transform.
	///
	/// A `Transform` can only be executed once. Therefore, the only valid state
	/// transitions are: `initial` → `running`; `running` → `success` | `error`
	enum State {
		case initial, running, success, error
	}

	/// Creates an instance combining the provided importer and exporter.
	public init(importer: ImportPass, exporter: ExportPass) {
		self.importer = importer
		self.exporter = exporter
	}

	/// Publisher for status updates from and interaction with the transform.
	///
	/// - Important: It is undefined on which thread or queue clients receive
	///   values from the publisher. Do not assume the main thread or even the
	///   same thread between values.
	nonisolated public var publisher: Publisher {
		subject.eraseToAnyPublisher()
	}

	/// Execute the transform.
	///
	/// This function is asynchronous, so any long-running work will yield to
	/// the caller. For status updates and interacting with the transform like
	/// configuring options, you must subscribe to the `publisher` property.
	public func execute() async {
		precondition(state == .initial, "transform already executed")
		state = .running

		// remember when an error is issued asynchronously
		var errorTask: Task<Void, Never>?

		// make ourselves available to passes executing within this transform
		await Self.$current.withValue(self) {

			// update transform state on error
			let subscription = publisher.sink(
				receiveCompletion: { [self] in
					if case .failure = $0 {
						errorTask = Task(priority: .high) { await errorState() }
					}
				},
				receiveValue: { _ in })
			defer { subscription.cancel() }

			// install a fresh allocator for media tree node IDs
			await MediaTree.ID.$allocator.withValue(MediaTree.ID.Allocator()) {

				do {
					// the actual execution of importer and exporter
					var mediaTree = try await importer.run {
						try await importer.generate()
					}
					await clientInteraction(&mediaTree) { .mediaTree($0) }
					try await exporter.run {
						try await exporter.consume(mediaTree)
					}
					subject.send(completion: .finished)
				} catch {
					subject.send(completion: .failure(error))
				}
			}
		}

		// wait for any error state change to manifest
		let _ = await errorTask?.result

		if state == .running { state = .success }
		assert(state == .success || state == .error)
	}

	/// Execute the transform.
	///
	/// This function returns immediately, while the transform runs in the
	/// background. For status updates and interacting with the transform like
	/// configuring options, you must subscribe to the `publisher` property.
	nonisolated public func execute() {
		Task(priority: .utility) { await execute() }
	}
}

extension Transform: CustomStringConvertible {
	nonisolated public var description: String { "\(importer) → \(exporter)" }
}

extension Transform {

	/// Indicate an error in the internal state
	///
	/// - ToDo: Replace with `async` property setter once support for effectful
	///   mutable properties is available.
	private func errorState() { state = .error }
}


/* MARK: Status Updates */

extension Transform {

	/// Status updates from the transform.
	public enum Status {

		/// A log message that can be shown to the user.
		case message(level: OSLogType, String.LocalizationValue)

		/// Shows progress of a long-running operation to the user.
		case progress(Progress)

		/// Allows inspection and editing of an intermediate media tree.
		case mediaTree(Interaction<MediaTree>)
	}
}

extension Transform {

	/// Wait for a client interaction that may mutate the given value.
	///
	/// Status updates are passed to the client via the transform publisher.
	/// Many of these updates are purely informational, but some require
	/// feedback from the client. Use this method to send such a status update
	/// and wait for the client to respond.
	///
	/// - Parameter value: The value presented to and mutated by the client.
	/// - Parameter body: A closure that constructs a `Status` from the given
	///   `Interaction`. This `Status` is then sent to the client via the
	///   transform publisher.
	func clientInteraction<Value>(_ value: inout Value, _ body: (Status.Interaction<Value>) -> Status) async {
		value = await withCheckedContinuation {
			let interaction = Status.Interaction(value: value, continuation: $0)
			subject.send(body(interaction))
		}
	}
}

extension Transform.Status {

	/// Manages status updates that can be interacted with by the client.
	///
	/// Clients receiving such a status can interact with the `value`
	/// property, including mutating changes to it. Afterwards, the client
	/// should call `finish()` exactly once.
	@dynamicMemberLookup
	public class Interaction<Value> {
		private let continuation: CheckedContinuation<Value, Never>
		private var finished: Bool = false
		public var value: Value

		init(value: Value, continuation: CheckedContinuation<Value, Never>) {
			self.value = value
			self.continuation = continuation
		}

		public func finish() {
			guard !finished else { return }
			continuation.resume(returning: value)
			finished = true
		}

		deinit { finish() }

		subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
			get { value[keyPath: keyPath] }
		}
		subscript<T>(dynamicMember keyPath: WritableKeyPath<Value, T>) -> T {
			get { value[keyPath: keyPath] }
			set { value[keyPath: keyPath] = newValue }
		}
	}
}


/* MARK: Accessors for Passes */

extension Transform {

	/// Access to the currently executing transform.
	///
	/// This property will be populated for the duration of `execute()`, which
	/// encompasses all calls to `ImportPass.generate()`, `Pass.process()`, or
	/// `ExportPass.consume()`.
	///
	/// - Returns: The current `Transform` when called from a `Pass` running as
	///   part of the transform. `nil` for callers from other contexts.
	@TaskLocal
	private static var current: Transform?

	/// The internal state of the currently executing transform.
	///
	/// A `Pass` can check the internal state for an error condition. If an
	/// error is indicated, the pass can cancel the task it is running on.
	///
	/// - Returns: The current transform `State` when called from a `Pass`
	///   running as part of the transform. `nil` for callers from other
	///   contexts.
	static var state: State? {
		get async { await self.current?.state }
	}

	/// The subject of the currently executing transform.
	///
	/// A `Pass` can send status updates into this subject and should subscribe
	/// any upstream publishers it may use internally.
	///
	/// - Returns: The current `Subject` when called from a `Pass` running as
	///   part of the transform. A generic logging `Subject` for callers from
	///   other contexts.
	public static var subject: Subject {
		self.current?.subject ?? Subject(logging: true)
	}
}


/* MARK: Subject and Publisher */

extension Transform {

	/// Publisher for asynchronous updates from the transform.
	public typealias Publisher = AnyPublisher<Status, Error>

	/// Subject by which a `Pass` can send updates.
	///
	/// Wraps a `PassthroughSubject` and therefore matches its external
	/// behavior. The important addition is that an internal `Logging` instance
	/// is automatically subscribed.
	///
	/// - SeeAlso: `Transform.Logging`
	/// - Remark: Subclassing `PassthroughSubject` would be preferable, but
	///   is not possible because it is declared `final`.
	public class Subject: Combine.Subject {
		public typealias Output = Transform.Publisher.Output
		public typealias Failure = Transform.Publisher.Failure

		private let wrapped = PassthroughSubject<Output, Failure>()

		init(logging: Bool) {
			// default logging subscriber
			if logging { wrapped.subscribe(Logging()) }
		}

		public func send(_ value: Output) {
			wrapped.send(value)
		}
		public func send(completion: Subscribers.Completion<Failure>) {
			wrapped.send(completion: completion)
		}
		public func send(subscription: Subscription) {
			wrapped.send(subscription: subscription)
		}
		public func receive<Downstream: Subscriber>(subscriber: Downstream) where Downstream.Input == Output, Downstream.Failure == Failure {
			wrapped.subscribe(subscriber)
		}
	}

	/// Logging for transform publisher output.
	///
	/// The transform `Subject` automatically subscribes a `Logging` instance.
	///
	/// - SeeAlso: `Transform.Subject`
	private class Logging: Subscriber {
		typealias Input = Transform.Publisher.Output
		typealias Failure = Transform.Publisher.Failure

		private static let logger = Logger(
			subsystem: Bundle.main.bundleIdentifier ?? "de.reactorcontrol.movie-archive",
			category: "transform")
		private func log(level: OSLogType, _ text: String) {
			Self.logger.log(level: level, "\(text)")
#if DEBUG
			print(level, text, separator: ": ")
#endif
		}

		func receive(subscription: Subscription) {
			subscription.request(.unlimited)
		}

		func receive(_ input: Input) -> Subscribers.Demand {
			switch input {
			case .message(level: let level, let text):
				log(level: level, String(unlocalized: text))
			case .progress(let progress):
				log(level: .info, "started " + String(unlocalized: progress.localization))
			case .mediaTree(_):
				log(level: .debug, "interaction with media tree")
			}
			return .none
		}

		func receive(completion: Subscribers.Completion<Failure>) {
			switch completion {
			case .finished:
				log(level: .info, "transform finished")
			case .failure(let error):
				log(level: .error, String(describing: error))
			}
		}
	}
}

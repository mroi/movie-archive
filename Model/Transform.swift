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
public class Transform {

	let importer: ImportPass
	let exporter: ExportPass

	let subject = Subject(logging: true)

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
	public var publisher: Publisher {
		subject.eraseToAnyPublisher()
	}

	/// Execute the transform.
	///
	/// This function is asynchronous, so any long-running work will yield to
	/// the caller. For status updates and interacting with the transform like
	/// configuring options, you must subscribe to the `publisher` property.
	public func execute() async {
		// reference cycle keeps the transform alive until execution is finished
		Transform.current = self
		defer { Transform.current = nil }

		// TODO: subscribe to publisher to cancel transform on failure

		// install a fresh allocator for media tree node IDs
		await MediaTree.ID.$allocator.withValue(MediaTree.ID.Allocator()) {

			do {
				// the actual execution of importer and exporter
				let mediaTree = try await importer.run {
					try await importer.generate()
				}
				try await exporter.run {
					try await exporter.consume(mediaTree)
				}
				subject.send(completion: .finished)
			} catch {
				subject.send(completion: .failure(error))
			}
		}
	}
}

extension Transform: CustomStringConvertible {
	public var description: String { "\(importer) → \(exporter)" }
}


/* MARK: Status Updates */

extension Transform {

	/// Status updates from the transform.
	public enum Status {

		/// A log message that can be shown to the user.
		case message(level: OSLogType, String.LocalizationValue)

		/// Shows progress of a long-running operation to the user.
		case progress(Progress)
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
	private static var current: Transform?  // TODO: change to @TaskLocal property

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

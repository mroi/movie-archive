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

	let subject = Subject()

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
	public func execute() {  // TODO: convert to async function
		// TODO: set up publisher
		do {
			let mediaTree = try importer.generate()
			try exporter.consume(mediaTree)
			subject.send(completion: .finished)
		} catch {
			subject.send(completion: .failure(error))
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
	}
}


/* MARK: Subject and Publisher */

extension Transform {

	/// Publisher for asynchronous updates from the transform.
	public typealias Publisher = AnyPublisher<Status, Error>

	/// Subject by which a `Pass` can send updates.
	// FIXME: wrap in a custom subject which automatically subscribes a logger
	public typealias Subject = PassthroughSubject<Publisher.Output, Publisher.Failure>
}

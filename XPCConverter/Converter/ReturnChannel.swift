import Foundation
import Combine
import os


/* MARK: Publisher for Updates */

/// Publisher to receive status updates from the converter service.
public typealias ConverterPublisher = AnyPublisher<ConverterOutput, ConverterError>

/// Status updates from the converter service.
public enum ConverterOutput {
	case message(level: OSLogType, String)
	case progress(Progress)
}

/// Error conditions in the converter service.
///
/// The two connection error cases can happen out-of-band at any time and are
/// therefore delivered asynchronously on a `ConverterPublisher`. Other errors
/// are thrown to immediately unwind control flow.
public enum ConverterError: Error {
	case sourceNotSupported
	case sourceReadError
	case connectionInvalid
	case connectionInterrupted
}


/* MARK: XPC Return Channel */

/// Interface by which the XPC service can push updates to the client.
///
/// XPC connections always operate in both directions, so it is possible for
/// the service to notify the client of changes asynchronously.
///
/// - Note: This is a low-level interface. Clients use the `ConverterPublisher`.
@objc public protocol ReturnInterface {
	func sendMessage(level: OSLogType, _ text: String)
	func sendProgress(id: UUID, completed: Int64, total: Int64, description: String)
	func sendConnectionInvalid()
	func sendConnectionInterrupted()
}

/// Adapts updates coming in via the XPC `ReturnInterface` to a `ConverterPublisher`.
class ReturnImplementation: NSObject, ReturnInterface {

	private let subject = PassthroughSubject<ConverterPublisher.Output, ConverterPublisher.Failure>()

	var publisher: ConverterPublisher {
		return subject.eraseToAnyPublisher()
	}

	private var progress: [UUID: Progress] = [:]

	func sendMessage(level: OSLogType, _ text: String) {
		subject.send(.message(level: level, text))
	}
	func sendProgress(id: UUID, completed: Int64, total: Int64, description: String) {
		if let currentProgress = progress[id] {
			currentProgress.completedUnitCount = completed
			currentProgress.totalUnitCount = total
			currentProgress.localizedDescription = description
		} else {
			let currentProgress = Progress.discreteProgress(totalUnitCount: total)
			currentProgress.completedUnitCount = completed
			currentProgress.localizedDescription = description
			progress.updateValue(currentProgress, forKey: id)
			subject.send(.progress(currentProgress))
			// we only ever add instances and rely on class deinit to destroy them
		}
	}
	func sendConnectionInvalid() {
		subject.send(completion: .failure(.connectionInvalid))
	}
	func sendConnectionInterrupted() {
		subject.send(completion: .failure(.connectionInterrupted))
	}

	deinit {
		subject.send(completion: .finished)
	}
}

import Foundation
import Combine


/* MARK: Publisher for Updates */

/// Publisher to receive status updates from the converter service.
public typealias ConverterPublisher = AnyPublisher<ConverterOutput, ConverterError>

/// Status updates from the converter service.
public enum ConverterOutput {
	// TODO: progress reporting and log messages
}

/// Error conditions in the converter service.
///
/// The two connection error cases can happen out-of-band at any time and are
/// therefore delivered asynchronously on a `ConverterPublisher`. Other errors
/// are thrown to immediately unwind control flow.
public enum ConverterError: Error {
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
	func sendConnectionInvalid()
	func sendConnectionInterrupted()
}

/// Adapts updates coming in via the XPC `ReturnInterface` to a `ConverterPublisher`.
class ReturnImplementation: NSObject, ReturnInterface {

	private let subject = PassthroughSubject<ConverterPublisher.Output, ConverterPublisher.Failure>()

	var publisher: ConverterPublisher {
		return subject.eraseToAnyPublisher()
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

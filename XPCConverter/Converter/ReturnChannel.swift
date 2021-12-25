import Foundation
import Combine
import os


/* MARK: Publisher for Updates */

/// Publisher to receive status updates from the converter service.
public typealias ConverterPublisher = AnyPublisher<ConverterOutput, ConverterError>

/// Status updates from the converter service.
public enum ConverterOutput {
	case message(level: OSLogType, String.LocalizationValue)
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

extension ConverterError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .sourceNotSupported:
			return String(localized: "source not supported")
		case .sourceReadError:
			return String(localized: "error reading from source")
		case .connectionInvalid:
			return String(localized: "internal component unavailable")
		case .connectionInterrupted:
			return String(localized: "processing interrupted unexpectedly")
		}
	}
}


/* MARK: XPC Return Channel */

/// Interface by which the XPC service can push updates to the client.
///
/// XPC connections always operate in both directions, so it is possible for
/// the service to notify the client of changes asynchronously.
///
/// - Note: This is a low-level interface. Clients use the `ConverterPublisher`.
@objc public protocol ReturnInterface {
	func sendMessage(level: OSLogType, _ text: StringLocalizationKey)
	func sendProgress(id: UUID, completed: Int64, total: Int64, description: StringLocalizationKey)
	func sendConnectionInvalid()
	func sendConnectionInterrupted()
}

/// A non-interpolated string which is used as a localization key.
///
/// It would be preferrable to use `String.LocalizationValue` here, but this type
/// is not `@objc` compatible and thus cannot be used in an XPC protocol. We
/// therefore pass regular strings, which are converted to
/// `String.LocalizationValue` when received.
///
/// Consequently, these strings must be static, non-interpolated instances.
/// Otherwise, using them as lookup keys in the localization tables will not
/// result in a match. This requirement is not enforced by the type system.
public typealias StringLocalizationKey = String


/// Adapts updates coming in via the XPC `ReturnInterface` to a `ConverterPublisher`.
class ReturnImplementation: NSObject, ReturnInterface {

	private let subject = PassthroughSubject<ConverterPublisher.Output, ConverterPublisher.Failure>()

	var publisher: ConverterPublisher {
		return subject.eraseToAnyPublisher()
	}

	private var progress: [UUID: Progress] = [:]

	func sendMessage(level: OSLogType, _ text: StringLocalizationKey) {
		subject.send(.message(level: level, String.LocalizationValue(text)))
	}
	func sendProgress(id: UUID, completed: Int64, total: Int64, description: StringLocalizationKey) {
		// manually keep in sync with ProgressUserInfoKey.localizationKey in the model
		let localizationKey = ProgressUserInfoKey(rawValue: "StringLocalizationKey")
		let description = String.LocalizationValue(description)

		if let currentProgress = progress[id] {
			currentProgress.totalUnitCount = total
			currentProgress.completedUnitCount = completed
			currentProgress.localizedDescription = String(localized: description)
			currentProgress.setUserInfoObject(description, forKey: localizationKey)
		} else {
			let currentProgress = Progress.discreteProgress(totalUnitCount: total)
			currentProgress.completedUnitCount = completed
			currentProgress.localizedDescription = String(localized: description)
			currentProgress.setUserInfoObject(description, forKey: localizationKey)
			currentProgress.localizedAdditionalDescription = ""
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

import Foundation


/// Reads and interprets DVD data structures.
///
/// This actor accesses `libdvdread` functionality in the XPC converter service.
/// It manages the lifetime of the corresponding `libdvdread` state.
public actor DVDReader {

	private let connection = ConverterConnection<ConverterDVDReader>()
	private var remoteStateID: UUID

	/// Publisher to receive status updates for DVD reader operations.
	///
	/// - Important: Because XPC requests run on an internal serial queue,
	///   clients must expect to receive values on an undefined thread.
	public var publisher: ConverterPublisher { connection.publisher }

	/// Initializes a DVD reader for the given URL
	public init(source url: URL) async throws {
		remoteStateID = try await connection.withErrorHandling { remote, done in
			remote.open(url) { result in
				if let result = result {
					done(.success(result))
				} else {
					done(.failure(.sourceNotSupported))
				}
			}
		}
	}

	/// Aggregated meta-information about the DVD.
	///
	/// The information is fetched from the DVD by performing an asynchronous
	/// XPC request. A single `Progress` instance is sent through the
	/// `publisher` so clients can observe progress.
	///
	/// Information is collected by reading the IFO files and menu NAV packets
	/// on the DVD.
	public func info() async throws -> DVDInfo {
		return try await connection.withErrorHandling { remote, done in

			remote.readInfo(remoteStateID) { result in
				do {
					guard let result = result else { throw ConverterError.sourceReadError }
					let unarchiver = try NSKeyedUnarchiver(forReadingFrom: result)
					let info = try unarchiver.decodeTopLevelDecodable(DVDInfo.self, forKey: NSKeyedArchiveRootObjectKey)
					guard let info = info else { throw ConverterError.sourceReadError }
					done(.success(info))
				} catch {
					done(.failure(.sourceReadError))
				}
			}
		}
	}

	deinit {
		connection.remote.close(remoteStateID)
	}
}

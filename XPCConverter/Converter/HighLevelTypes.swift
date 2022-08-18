import Foundation


/* MARK: DVDReader */

/// Reads and interprets DVD data structures.
///
/// This client-side type accesses `libdvdread` functionality in the XPC
/// converter service. It manages the lifetime of the corresponding `libdvdread`
/// state.
public final class DVDReader: ConverterConnection<ConverterDVDReader> {

	private var readerStateID: UUID!

	/// Initializes a DVD reader for the given URL
	public init(source url: URL) async throws {
		super.init()

		readerStateID = try await withErrorHandling { done in
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
		return try await withErrorHandling { done in

			remote.readInfo(readerStateID) { result in
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
		if readerStateID != nil {
			remote.close(readerStateID)
		}
	}
}

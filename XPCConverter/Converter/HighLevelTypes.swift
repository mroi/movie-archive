import Foundation


/* MARK: DVDReader */

/// Reads and interprets DVD data structures.
///
/// This client-side type accesses `libdvdread` functionality in the XPC
/// converter service. It manages the lifetime of the corresponding `libdvdread`
/// state.
public final class DVDReader: ConverterClient<ConverterDVDReader> {

	private var readerStateID: UUID!

	/// Initializes a DVD reader for the given URL
	public init(source url: URL) throws {
		super.init()

		readerStateID = try withConnectionErrorHandling { done in
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
	public func info() throws -> DVDInfo {
		return try withConnectionErrorHandling { done in

			remote.readInfo(readerStateID) { 
				done(.failure(.sourceReadError))
			}
		}
	}

	deinit {
		if readerStateID != nil {
			remote.close(readerStateID)
		}
	}
}

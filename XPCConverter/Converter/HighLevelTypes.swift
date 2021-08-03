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

	deinit {
		if readerStateID != nil {
			remote.close(readerStateID)
		}
	}
}

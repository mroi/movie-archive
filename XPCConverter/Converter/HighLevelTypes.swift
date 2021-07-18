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

		// listen for asynchronous errors
		var done = false
		var error: ConverterError?
		let subscription = publisher.sink {
			switch $0 {
			case .failure(let publishedError):
				error = publishedError
			case .finished:
				error = .connectionInterrupted
			}
			done = true
		} receiveValue: { _ in
		}
		defer { subscription.cancel() }

		// invoke the converter operation
		var id: UUID?
		remote.open(url) { result in
			DispatchQueue.main.async { id = result; done = true }
		}

		waitForAsync(until: done)

		guard let id = id else {
			if let error = error {
				throw error
			} else {
				throw ConverterError.sourceNotSupported
			}
		}

		readerStateID = id
	}

	// TODO: replace with Swift concurrency
	private func waitForAsync(until predicate: @autoclosure () -> Bool) {
		while !predicate() {
			RunLoop.current.run(mode: .default, before: .distantFuture)
		}
	}

	deinit {
		if readerStateID != nil {
			remote.close(readerStateID)
		}
	}
}

import Foundation
import Combine


/// Functions from `libdvdread` for reading and interpreting DVD data structures.
@objc public protocol ConverterDVDReader {
	func open(_ url: URL, completionHandler: @escaping (_ result: UUID?) -> Void)
	func readInfo(_ id: UUID, completionHandler: @escaping (_ result: Data?) -> Void)
	func close(_ id: UUID)
}

/// Aggregate interface of all converter interfaces.
///
/// - Note: In case of an XPC connection error, completion handlers are
///   not called. Therefore, these interfaces should not be converted from
///   completion handlers to `async` functions, because not calling the
///   completion handler will leave partial tasks dangling in the async runtime.
@objc public protocol ConverterInterface: ConverterDVDReader {}


/// Low-level access the converter functionality.
///
/// To isolate potentially unsafe code, complex conversion operations are
/// provided by an XPC service. These operations are grouped in interface
/// protocols. A client-side proxy object implementing one of these interfaces
/// is provided by an instance of this class.
///
/// At the same time, the XPC service can send asynchronous feedback to the
/// client by way of the `ConverterPublisher`.
///
/// - Remark: These low-level XPC types form a conduit which is meant to be
///   wrapped with higher-level types like `DVDReader` for client consumption.
class ConverterConnection<Interface> {

	/// Publisher to receive status updates from the converter service.
	///
	/// - Important: Because XPC requests run on an internal serial queue,
	///   clients must expect to receive values on an undefined thread.
	let publisher: ConverterPublisher

	let remote: Interface
	private let connection: NSXPCConnection
	private let subscription: AnyCancellable?

	/// Sets up a client instance managing one XPC connection.
	init() {
#if DEBUG
		if let injected = ConverterConnection<Any>.injected {
			remote = injected.proxy as! Interface
			publisher = injected.publisher
			connection = NSXPCConnection()
			subscription = nil
			return
		}
#endif

		let returnChannel = ReturnImplementation()
		connection = ConverterConnection<Interface>.makeConnection()
		connection.remoteObjectInterface = NSXPCInterface(with: ConverterInterface.self)
		connection.exportedInterface = NSXPCInterface(with: ReturnInterface.self)
		connection.exportedObject = returnChannel
		connection.invalidationHandler = { returnChannel.sendConnectionInvalid() }
		connection.interruptionHandler = { returnChannel.sendConnectionInterrupted() }
		connection.resume()

		remote = connection.remoteObjectProxy as! Interface
		publisher = returnChannel.publisher

		// invalidate the connection whenever the publisher completes
		subscription = publisher.sink(
			receiveCompletion: { [weak connection] _ in connection?.invalidate() },
			receiveValue: { _ in })
	}

	deinit {
		connection.invalidate()
	}

	/// Creates a connection to the XPC service.
	private static func makeConnection() -> NSXPCConnection {
		let name = "de.reactorcontrol.movie-archive.converter"
#if DEBUG
		if Bundle.main.bundleIdentifier == "com.apple.dt.Xcode.PlaygroundStub-macosx" {
			// Playground execution: XPC service needs to be manually registered
			let port = CFMessagePortCreateRemote(nil, name as CFString)
			guard port != nil else {
				print("To use the Converter XPC service from a Playground, " +
				      "it needs to be manually registered with launchd:")
				print("launchctl bootstrap gui/\(getuid()) <path to Converter.xpc>")
				fatalError()
			}
			CFMessagePortInvalidate(port)
			return NSXPCConnection(machServiceName: name)
		}
#endif
		return NSXPCConnection(serviceName: name)
	}
}


extension ConverterConnection {

	/// Wrap a remote converter invocation with connection error handling.
	///
	/// When invoking a remote function, XPC guarantees that either the
	/// function’s completion handler or one of the connection’s error handlers
	/// is called. Consequently, in the error case, the completion handler is
	/// never called and code not checking for connection errors will be stuck.
	///
	/// The connection errors will surface as failures on `publisher`, so this
	/// wrapper listens for such failures and throws them. Best practice is to
	/// wrap every remote invocation individually.
	///
	/// - Parameter body: A closure invoking a remote function. The closure
	///   receives the remote interface as first parameter and a continuation
	///   function as second parameter. When the remote call completes
	///   successfully, the continuation function must be called exactly once.
	/// - Returns: Successful results are returned, errors are thrown.
	func withErrorHandling<T>(_ body: (Interface, @escaping (Result<T, ConverterError>) -> Void) -> Void) async throws -> T {

		return try await withCheckedThrowingContinuation { continuation in

			// listen for asynchronous errors from the publisher
			let subscription = publisher.sink(
				receiveCompletion: {
					switch $0 {
					case .failure(let error):
						continuation.resume(with: .failure(error))
					case .finished:
						continuation.resume(with: .failure(ConverterError.connectionInterrupted))
					}
				},
				receiveValue: { _ in })
			defer { subscription.cancel() }

			// run caller code
			body(remote) { continuation.resume(with: $0) }
		}
	}
}


#if DEBUG
extension ConverterConnection where Interface == Any {

	/// Injects mock implementations for testing.
	static func withMocks(proxy: Interface, publisher: ConverterPublisher? = nil,
	                      _ body: () async throws -> ()) async rethrows {
		let emptyPublisher = Empty<ConverterOutput, ConverterError>(completeImmediately: false).eraseToAnyPublisher()
		let inject = (proxy, publisher ?? emptyPublisher)
		try await $injected.withValue(inject) {
			try await body()
		}
	}

	@TaskLocal
	private static var injected: (proxy: Interface, publisher: ConverterPublisher)?
}
#endif

import Foundation
import Combine


/// Aggregate interface of all converter interfaces.
@objc public protocol ConverterInterface {}


/// Low-level access the converter functionality.
///
/// To isolate potentially unsafe code, complex conversion operations are
/// provided by an XPC service. These operations are grouped in interface
/// protocols. A client-side proxy object implementing one of these interfaces
/// is provided by an instance of this class.
///
/// At the same time, the XPC service can send asynchronous feedback to the
/// client by way of the `ConverterPublisher`.
public class ConverterClient<ProxyInterface> {

	/// Publisher to receive status updates from the converter service.
	///
	/// - Important: Because XPC requests run on an internal serial queue,
	///   clients must expect to receive values on an undefined thread.
	public let publisher: ConverterPublisher

	let remote: ProxyInterface
	private let connection: NSXPCConnection
	private let subscription: AnyCancellable?

	/// Sets up a client instance managing one XPC connection.
	init() {
#if DEBUG
		if let injected = ConverterClient<Any>.injected {
			remote = injected.proxy as! ProxyInterface
			publisher = injected.publisher
			connection = NSXPCConnection()
			subscription = nil
			return
		}
#endif

		let returnChannel = ReturnImplementation()
		connection = ConverterClient<ProxyInterface>.makeConnection()
		connection.remoteObjectInterface = NSXPCInterface(with: ConverterInterface.self)
		connection.exportedInterface = NSXPCInterface(with: ReturnInterface.self)
		connection.exportedObject = returnChannel
		connection.invalidationHandler = { returnChannel.sendConnectionInvalid() }
		connection.interruptionHandler = { returnChannel.sendConnectionInterrupted() }
		connection.resume()

		remote = connection.remoteObjectProxy as! ProxyInterface
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


extension ConverterClient {

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
	///   receives a continuation function which must be called exactly once
	///   if the remote function’s completion handler is called.
	/// - Returns: Successful results are returned, errors are thrown.
	func withConnectionErrorHandling<T>(_ body: (_ done: @escaping (Result<T, ConverterError>) -> Void) -> Void) throws -> T {

		// TODO: replace semaphore with async continuation to not block the caller
		let resultAvailable = DispatchSemaphore(value: 0)
		var result: Result<T, ConverterError>?

		// set the result exclusively and only once via this function
		func setResult(_ value: Result<T, ConverterError>) {
			assert(result == nil)
			result = value  // race-free: called on some thread, but only once
			resultAvailable.signal()
		}

		// listen for asynchronous errors from the publisher
		let subscription = publisher.sink(
			receiveCompletion: {
				switch $0 {
				case .failure(let error):
					setResult(.failure(error))
				case .finished:
					setResult(.failure(.connectionInterrupted))
				}
			},
			receiveValue: { _ in })
		defer { subscription.cancel() }

		// run caller code
		body(setResult)

		// wait for continuation, result is definitely valid after this line
		resultAvailable.wait()

		return try result!.get()
	}
}


#if DEBUG
extension ConverterClient where ProxyInterface == Any {
	// TODO: change to @TaskLocal property

	/// Injects mock implementations for testing.
	static func withMocks(proxy: ProxyInterface, publisher: ConverterPublisher? = nil,
	                      _ body: () throws -> ()) rethrows {
		let emptyPublisher = Empty<ConverterOutput, ConverterError>(completeImmediately: false).eraseToAnyPublisher()
		injected = (proxy, publisher ?? emptyPublisher)
		try body()
		injected = nil
	}

	private static var injected: (proxy: ProxyInterface, publisher: ConverterPublisher)?
}
#endif

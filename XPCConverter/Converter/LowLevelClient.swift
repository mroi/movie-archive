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
		let returnChannel = ReturnImplementation()
		connection = ConverterClient<ProxyInterface>.makeConnection()
		connection.remoteObjectInterface = NSXPCInterface(with: ConverterInterface.self)
		connection.exportedInterface = NSXPCInterface(with: ReturnInterface.self)
		connection.exportedObject = returnChannel
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

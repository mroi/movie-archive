import Foundation


/// Aggregate interface of all converter interfaces.
@objc public protocol ConverterInterface {}


/// Low-level access the converter functionality.
///
/// To isolate potentially unsafe code, complex conversion operations are
/// provided by an XPC service. These operations are grouped in interface
/// protocols. A client-side proxy object implementing one of these interfaces
/// is provided by an instance of this class.
public class ConverterClient<ProxyInterface> {

	let remote: ProxyInterface
	private let connection: NSXPCConnection

	/// Sets up a client instance managing one XPC connection.
	init() {
		connection = ConverterClient<ProxyInterface>.makeConnection()
		connection.remoteObjectInterface = NSXPCInterface(with: ConverterInterface.self)
		connection.resume()

		remote = connection.remoteObjectProxy as! ProxyInterface
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

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
		connection = NSXPCConnection(serviceName: "de.reactorcontrol.movie-archive.converter")
		connection.remoteObjectInterface = NSXPCInterface(with: ConverterInterface.self)
		connection.resume()

		remote = connection.remoteObjectProxy as! ProxyInterface
	}

	deinit {
		connection.invalidate()
	}
}

import Foundation
import MovieArchiveConverter


/// Implementation of the XPC functionality.
///
/// A new implementation instance is created per connection to the XPC service.
/// Functions are called on an internal serial queue, so per instance, all
/// operations are single-threaded.
class ConverterImplementation: NSObject {}

class ConverterDelegate: NSObject, NSXPCListenerDelegate {
	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
		connection.exportedInterface = NSXPCInterface(with: ConverterInterface.self)
		connection.exportedObject = ConverterImplementation()
		connection.resume()
		return true
	}
}

let delegate = ConverterDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()

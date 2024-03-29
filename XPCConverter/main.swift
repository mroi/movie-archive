import Foundation
import MovieArchiveConverter


/// Implementation of the XPC functionality.
///
/// A new implementation instance is created per connection to the XPC service.
/// Functions are called on an internal serial queue, so per instance, all
/// operations are single-threaded.
class ConverterImplementation: NSObject {

	/// Stores state of external libraries across function calls.
	///
	/// Each stored pointer has a cleanup handler stored next to it. This
	/// handler gets called in case of XPC connection invalidation.
	var state: [UUID: (pointer: OpaquePointer, cleanup: () -> Void)] = [:]

	/// Fetches the proxy object for the return channel to the client.
	var returnChannel: ReturnInterface? {
		let proxy = NSXPCConnection.current()?.remoteObjectProxy
		return proxy as? ReturnInterface
	}

	deinit {
		// run all cleanup handlers
		for (_, cleanup) in state.values { cleanup() }
	}
}

class ConverterDelegate: NSObject, NSXPCListenerDelegate {
	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
		connection.remoteObjectInterface = NSXPCInterface(with: ReturnInterface.self)
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

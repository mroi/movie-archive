import Foundation


@objc public protocol ConverterProtocol {
}

class Converter: NSObject, ConverterProtocol {
}

class ConverterDelegate: NSObject, NSXPCListenerDelegate {
	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
		let exportedObject = Converter()
		connection.exportedInterface = NSXPCInterface(with: ConverterProtocol.self)
		connection.exportedObject = exportedObject
		connection.resume()
		return true
	}
}

let delegate = ConverterDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()

import SwiftUI


public struct ContentView: View {
	public init() {}
	public var body: some View {
		Text("Hello, World!")
			.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}


struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

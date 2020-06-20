import SwiftUI


public struct TestView: View {
	public static let `default`: NSView = NSHostingView(rootView: TestView())
	public var body: some View {
		Text("Hello, World!")
			.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}


struct TestView_Previews: PreviewProvider {
	static var previews: some View {
		TestView()
	}
}

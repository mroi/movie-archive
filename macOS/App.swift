import SwiftUI


@main
struct TestApp: App {
	var body: some Scene {
		DocumentGroup(newDocument: ImportDocument()) { file in
			ImportDocumentView(document: file.$document)
		}
	}
}

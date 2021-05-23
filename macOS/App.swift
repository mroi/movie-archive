import SwiftUI


@main
struct TestApp: App {
	var body: some Scene {
		DocumentGroup(newDocument: IngestDocument()) { file in
			IngestDocumentView(document: file.$document)
		}
	}
}

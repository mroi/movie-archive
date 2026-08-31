import XCTest


@MainActor
class UIMacOS: XCTestCase {

	let app = {
		let app = XCUIApplication()
		app.launch()
		return app
	}()

	override func setUp() {
		continueAfterFailure = false
	}
}

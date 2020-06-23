import XCTest


class UIMacOS: XCTestCase {

	let app = XCUIApplication()

	override func setUp() {
		continueAfterFailure = false
		app.launch()
	}
}

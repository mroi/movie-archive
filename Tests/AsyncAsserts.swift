import XCTest


/// Add `async` versions of `XCTAssert` functions.
/// - ToDo: Remove this extension once native support is in `XCTest`.
extension XCTest {

	func XCTAssertEqualAsync<T: Equatable>(_ expression1: @autoclosure () async throws -> T, _ expression2: @autoclosure () async throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async rethrows {
		if try await expression1() != expression2() {
			XCTFail(message(), file: file, line: line)
		}
	}

	func XCTAssertThrowsErrorAsync<T>(_ expression: @autoclosure () async throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line, _ errorHandler: (_ error: Error) -> Void = { _ in }) async {
		do {
			let _ = try await expression()
			XCTFail(message(), file: file, line: line)
		} catch {
			errorHandler(error)
		}
	}

	func XCTAssertNoThrowAsync<T>(_ expression: @autoclosure () async throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async {
		do {
			let _ = try await expression()
		} catch {
			XCTFail(message(), file: file, line: line)
		}
	}
}

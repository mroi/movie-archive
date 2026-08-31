import Testing
import Foundation

@testable import MovieArchiveModel
@testable import MovieArchiveImporters
@testable import MovieArchiveConverter


/* MARK: Generic Importer Tests */

@Suite
struct ImporterTests {

	@Test
	func unsupportedSource() async {
		let source = URL(fileURLWithPath: "/var/empty")
		let error = await #expect(throws: Importer.Error.self) {
			try await Importer(source: source)
		}
		#expect(error == .sourceNotSupported)
	}
}


/* MARK: DVD Importer Tests */

@Suite
struct DVDImporterTests {

	/// The `Bundle` of this test target, can be used to access test resources.
	private var testBundle: Bundle { Bundle(for: BundleFinder.self) }
	private final class BundleFinder: NSObject {}

	@Test
	func readerInitDeinit() async {
		await confirmation("open should be called") { openCall in
			await confirmation("close should be called") { closeCall in

				class ReaderMock: ConverterDVDReader {
					let openCall: Confirmation
					let closeCall: Confirmation
					
					init(open: Confirmation, close: Confirmation) {
						openCall = open
						closeCall = close
					}
					func open(_: URL, completionHandler done: @escaping (UUID?) -> Void) {
						openCall.confirm()
						done(UUID())
					}
					func close(_: UUID) {
						closeCall.confirm()
					}
					func readInfo(_: UUID, completionHandler: @escaping (Data?) -> Void) {
						Issue.record("unexpected read")
					}
				}
				
				await ConverterConnection.withUnsafeMocks(proxy: ReaderMock(open: openCall, close: closeCall)) {
					let source = URL(fileURLWithPath: ".")
					await #expect(throws: Never.self) {
						try await DVDReader(source: source)
					}
				}
			}
		}
	}

	@Test
	func readInfoError() async throws {
		try await confirmation("read info should be called") { readCall in

			class ReaderMock: ConverterDVDReader {
				let readCall: Confirmation
				
				init(read: Confirmation) {
					readCall = read
				}
				func open(_: URL, completionHandler done: @escaping (UUID?) -> Void) {
					done(UUID())
				}
				func close(_: UUID) {}
				func readInfo(_: UUID, completionHandler done: @escaping (Data?) -> Void) {
					readCall.confirm()
					done(Data(base64Encoded: "broken archive"))
				}
			}

			try await ConverterConnection.withUnsafeMocks(proxy: ReaderMock(read: readCall)) {
				let source = URL(fileURLWithPath: ".")
				let reader = try await DVDReader(source: source)
				let error = await #expect(throws: ConverterError.self) {
					try await reader.info()
				}
				#expect(error == .sourceReadError)
			}
		}
	}

	@Test
	func dvdInfoJSON() async throws {
		// test struct with some custom JSON DVD info types
		struct DVDInfoTest: Codable {
			let duration: DVDInfo.Time
			let menu: DVDInfo.Domain.ProgramChains.Descriptor
			let title: DVDInfo.Domain.ProgramChains.Descriptor
		}

		let duration = DVDInfo.Time(hours: 1, minutes: 2, seconds: 3, frames: 4, rate: .framesPerSecond(25))
		let menu = DVDInfo.Domain.ProgramChains.Descriptor.menu(language: "eng", entryPoint: true, type: .titles, index: 3)
		let title = DVDInfo.Domain.ProgramChains.Descriptor.title(title: 1, entryPoint: true, index: 5)
		let test = DVDInfoTest(duration: duration, menu: menu, title: title)

		// encode DVD info to JSON and decode again
		let json = try JSON(test)
		print(json.string())
		let decoded = try json.decode()

		// decoded result re-encodes to the original JSON
		let json2 = try JSON(decoded)
		#expect(json.data == json2.data)
	}

	@Test
	func minimalDVD() async throws {
		let iso = testBundle.url(forResource: "MinimalDVD", withExtension: "iso")!
		let importer = try await Importer(source: iso)

		let transform = Transform(importer: importer, exporter: NullExporter())

		var outputs = 0
		let subscription = transform.publisher
			.mapError { _ in fatalError("unexpected publisher error") }
			.sink { _ in outputs += 1 }
		defer { subscription.cancel() }

		await transform.execute()

		#expect(await transform.state == .success)
		#expect(transform.description == "DVDImporter → NullExporter")
		#expect(outputs == 9)
	}
}

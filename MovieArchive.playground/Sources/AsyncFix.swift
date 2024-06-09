/* FIXME: Playgrounds with toplevel async code currently crash (FB11279184)
   actor Test {
     var value: Int

     init() { value = 0 }
     func increment() { value += 1 }
   }

   let t = Test()
   await t.increment()
   print(await t.value)
*/

import Foundation
import MovieArchiveImporters


extension Importer {
	public init(source: URL) throws {
		class UnsafeRacyStore: @unchecked Sendable {
			private var value: Result<Importer, Swift.Error>?
			let ready = DispatchSemaphore(value: 0)
			var result: Result<Importer, Swift.Error> {
				get { ready.wait() ; return value! }
				set { value = newValue ; ready.signal() }
			}
		}
		let store = UnsafeRacyStore()
		Task {
			do {
				let importer = try await Self.init(source: source)
				store.result = .success(importer)
			} catch {
				store.result = .failure(error)
			}
		}
		self = try store.result.get()
	}
}

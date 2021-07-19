import Foundation
import MovieArchiveConverter
import LibDVDRead


extension ConverterImplementation: ConverterDVDReader {

	static let disableCSSCache: Void = {
		setenv("DVDCSS_CACHE", "off", 1)
	}()

	public func open(_ url: URL, completionHandler done: @escaping (_ result: UUID?) -> Void) {
		Self.disableCSSCache

		if url.isFileURL, let reader = DVDOpen(url.path) {
			// make sure this looks like a DVD
			var statbuf = dvd_stat_t()
			let result = DVDFileStat(reader, 0, DVD_READ_INFO_FILE, &statbuf)

			if result == 0 {
				// valid DVD, remember reader state and return unique handle
				let id = UUID()
				state.updateValue(reader, forKey: id)
				// keep XPC service alive as long as there is active reader state
				xpc_transaction_begin()

				done(id)
				return
			}
		}
		done(.none)
	}

	func readIFOs(withHandle id: UUID, completionHandler done: @escaping () -> Void) {
		guard let reader = state[id] else { return }

		let vmgi = ifoOpen(reader, 0)
		guard let vmgi = vmgi else { return }
		defer { ifoClose(vmgi) }

		var vtsi: [Int: UnsafeMutablePointer<ifo_handle_t>] = [:]
		defer { vtsi.forEach { ifoClose($0.value) }	}

		let vtsCount = vmgi.pointee.vmgi_mat?.pointee.vmg_nr_of_title_sets ?? 0
		for vtsIndex in 1...99 {
			if vtsi.count == vtsCount { break }
			let vtsInfo = ifoOpen(reader, Int32(vtsIndex))
			guard let vtsInfo = vtsInfo else { continue }
			vtsi[vtsIndex] = vtsInfo
		}

		done()  // FIXME: return Swift struct with DVD info
	}

	public func close(_ id: UUID) {
		guard let reader = state[id] else { return }
		state.removeValue(forKey: id)
		DVDClose(reader)
		xpc_transaction_end()
	}
}

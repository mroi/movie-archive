import Foundation
import MovieArchiveConverter
import LibDVDRead


/* MARK: DVDReader Conformance */

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

	func readInfo(_ id: UUID, completionHandler done: @escaping (_ result: Data?) -> Void) {
		guard let reader = state[id] else { return done(nil) }

		do {
			let ifo = DVDData.IFO.Reader(reader: reader)

			// read Video Manager Information
			try ifo.read(.vmgi)

			// read Video Title Set Information
			let vmgCount = 1
			let vtsCount = ifo.data.vtsCount
			for vtsIndex in 1...99 {
				if ifo.data.count == vmgCount + vtsCount { break }
				do {
					let vtsi = DVDData.FileId.vtsi(vtsIndex)
					try ifo.read(vtsi)
				} catch {
					continue
				}
			}

			// convert DVD data to Swift struct
			guard let info = DVDInfo(ifo.data) else {
				throw DVDReaderError.dataImportError
			}

			// serialize for sending as result
			let archiver = NSKeyedArchiver(requiringSecureCoding: true)
			try archiver.encodeEncodable(info, forKey: NSKeyedArchiveRootObjectKey)
			archiver.finishEncoding()

			done(archiver.encodedData)

		} catch {
			done(nil)
		}
	}

	public func close(_ id: UUID) {
		guard let reader = state[id] else { return }
		state.removeValue(forKey: id)
		DVDClose(reader)
		xpc_transaction_end()
	}
}


/* MARK: DVD Data Collections */

/// Collections of raw data, obtained from the DVD via `libdvdread`.
///
/// The ingest of DVD data happens in two steps:
/// 1. The DVD data is read in its raw form via `libdvdread` functions. The
///    corresponding C data structures are stored within Swift collections.
/// 2. These Swift collections are passed to the toplevel initializer of
///    the `DVDInfo` type. This is a Swift struct offering a more usable
///    representation of this data.
enum DVDData {

	/// Identifies a file or file group of 2GB chunks on the DVD.
	enum FileId: Hashable {
		/// Video Manager Information (VMGI).
		///
		/// The Video Manager contains toplevel entry points of the DVD.
		case vmgi
		/// Video Title Set Information (VTSI).
		///
		/// The Video Title Sets are groups of playble content.
		case vtsi(_ index: Int)

		var rawValue: Int32 {
			switch self {
			case .vmgi: return 0
			case .vtsi(let titleSet): return Int32(titleSet)
			}
		}
	}

	/// Collection types for storing IFO data.
	///
	/// IFOs are files containing meta information about the DVD’s navigational
	/// and playback structure.
	enum IFO {
		typealias All = [FileId: IFOFile]
		typealias IFOFile = UnsafeMutablePointer<ifo_handle_t>
	}
}


/* MARK: Reading Data from the DVD */

private extension DVDData.IFO {
	/// Executes IFO read operations, reports progress, and maintains the resulting data.
	class Reader {
		var data: All = [:]
		private let reader: OpaquePointer

		init(reader: OpaquePointer) {
			self.reader = reader
		}

		func read(_ file: DVDData.FileId) throws {
			let ifoData = ifoOpen(reader, file.rawValue)
			guard let ifoData = ifoData else {
				throw DVDReaderError.readError
			}
			data[file] = ifoData
		}

		deinit {
			data.forEach { ifoClose($0.value) }
		}
	}
}


/* MARK: Extracting Properties */

private extension Dictionary where Key == DVDData.IFO.All.Key, Value == DVDData.IFO.All.Value {
	/// The number of Video Title Sets on the DVD.
	var vtsCount: Int {
		Int(self[.vmgi]?.pointee.vmgi_mat?.pointee.vmg_nr_of_title_sets ?? 0)
	}
}

/// Error conditions while reading and understanding DVD information.
private enum DVDReaderError: Error {
	case readError
	case dataImportError
}

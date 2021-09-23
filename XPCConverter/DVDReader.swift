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
			let progress = DVDData.Progress(channel: returnChannel)
			let ifo = DVDData.IFO.Reader(reader: reader, progress: progress)
			let nav = DVDData.NAV.Reader(reader: reader, progress: progress)

			// read Video Manager Information
			try ifo.read(.vmgi)

			// update expected amount of work
			let vmgCount = 1
			let vtsCount = ifo.data.vtsCount
			progress.expectedTotal = vmgCount + vtsCount

			// scan NAV packets within First Play and Video Manager Menu
			try nav.scan(.vmgi, within: ifo.data)

			// read Video Title Set Information
			for vtsIndex in 1...99 {
				if ifo.data.count == vmgCount + vtsCount { break }
				do {
					let vtsi = DVDData.FileId.vtsi(vtsIndex)
					try ifo.read(vtsi)
					try nav.scan(vtsi, within: ifo.data)
				} catch let error as DVDReaderError {
					returnChannel?.sendMessage(level: .error, error.rawValue)
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

		} catch let error as DVDReaderError {
			returnChannel?.sendMessage(level: .error, error.rawValue)
			done(nil)
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

	/// Identifies a playback domain within a file.
	enum DomainId: Hashable {
		case firstPlay
		case menus
		case titles

		var rawValue: dvd_read_domain_t {
			switch self {
			case .firstPlay: return DVD_READ_MENU_VOBS
			case .menus: return DVD_READ_MENU_VOBS
			case .titles: return DVD_READ_TITLE_VOBS
			}
		}
	}

	/// Identifies a concrete program chain within a domain.
	enum PGCId: Hashable {
		case firstPlay
		case menu(language: UInt32, pgc: UInt32)
		case title(pgc: UInt32)
	}

	/// Collection types for storing IFO data.
	///
	/// IFOs are files containing meta information about the DVD’s navigational
	/// and playback structure.
	enum IFO {
		typealias All = [FileId: IFOFile]
		typealias IFOFile = UnsafeMutablePointer<ifo_handle_t>
	}

	/// Collection types for storing NAV data.
	///
	/// Navigation packets are embedded within the MPEG program streams and
	/// contain information about interactive menus and directions for playback
	/// with multiple viewing angles.
	enum NAV {
		typealias All = [FileId: VTS]
		typealias VTS = [DomainId: Domain]
		typealias Domain = [PGCId: PGC]
		typealias PGC = [Cell]
		typealias Cell = [NAVPacket]
		typealias NAVPacket = (timestamp: UInt64?, pci: pci_t, dsi: dsi_t)
	}

	/// Types for handling of VOB data.
	///
	/// Video Objects are the files containing MPEG program stream data and
	/// NAV packets.
	enum VOB {
		/// A Video Object Unit is the smallest physically contiguous sequence of MPEG data.
		///
		/// Each VOBU starts with exactly one NAV packet.
		struct VOBU {
			/// Presentation Control Information (PCI).
			let pci: pci_t
			/// Data Search Information (DSI).
			let dsi: dsi_t
		}
	}
}


/* MARK: Reading Data from the DVD */

private extension DVDData {
	/// Progress reporting for the process of reading DVD data.
	class Progress {
		private let id = UUID()
		private let channel: ReturnInterface?

		/// Expected work items.
		var expectedTotal = 0 {
			didSet { report() }
		}
		/// Successfully completed items.
		var itemsCompleted = 0.0 {
			didSet { report() }
		}

		init(channel: ReturnInterface?) {
			self.channel = channel
			report()
		}

		/// Calculates and reports the current progress via the return channel.
		private func report() {
			let total = 1000 * Int64(expectedTotal)
			let completed = total > 0 ? Int64(1000 * itemsCompleted) : 0
			channel?.sendProgress(id: id, completed: completed, total: total,
			                      description: "reading DVD information")
		}
	}
}

private extension DVDData.IFO {
	/// Executes IFO read operations, reports progress, and maintains the resulting data.
	class Reader {
		var data: All = [:]
		private let reader: OpaquePointer
		private let progress: DVDData.Progress

		init(reader: OpaquePointer, progress: DVDData.Progress) {
			self.reader = reader
			self.progress = progress
			progress.itemsCompleted = Double(data.count)
		}

		func read(_ file: DVDData.FileId) throws {
			let ifoData = ifoOpen(reader, file.rawValue)
			guard let ifoData = ifoData else {
				switch file {
				case .vmgi: throw DVDReaderError.vmgiReadError
				case .vtsi: throw DVDReaderError.vtsiReadError
				}
			}
			data[file] = ifoData
			progress.itemsCompleted = Double(data.count)
		}

		deinit {
			progress.itemsCompleted = Double(data.count)
			data.forEach { ifoClose($0.value) }
		}
	}
}

private extension DVDData.NAV {
	/// Executes NAV scan operations, reports progress, and maintains the resulting data.
	class Reader {
		var data: All = [:]
		private let reader: OpaquePointer
		private let progress: DVDData.Progress

		init(reader: OpaquePointer, progress: DVDData.Progress) {
			self.reader = reader
			self.progress = progress
		}

		func scan(_ file: DVDData.FileId, within ifoData: DVDData.IFO.All) throws {
			let vtsData = ifoData.vtsNavCells(for: file)

			// FIXME: update progress with a fractional value

			let vtsNav = try vtsData.map { (domain, domainData) -> (DVDData.DomainId, Domain) in
				guard domainData.contains(where: { $0.value.count > 0 }) else {
					return (domain, [:])
				}
				let vob = try DVDData.VOB.Reader(file, domain: domain, reader: reader)

				let domainNav = domainData.mapValues { pgc -> PGC in
					return pgc.map { cell -> Cell in

						// read VOBUs of one cell
						let vobuSequence = vob.readCell(startingAt: Int(cell.first_sector))
						let vobus = vobuSequence.map { vobu in
							return vobu
						}

						// get PCI and DSI from VOBUs, calculate timestamp by summing the VOBU durations
						return vobus.reduce(into: []) { result, vobu in
							let timestamp: UInt64?
							if let previous = result.last {
								timestamp = previous.timestamp.map {
									let duration = previous.pci.pci_gi.vobu_e_ptm - previous.pci.pci_gi.vobu_s_ptm
									return $0 + UInt64(duration)
								}
							} else {
								timestamp = 0
							}
							let linearPlayback = !vobu.dsi.sml_pbi.category.bit(14)
							result.append((linearPlayback ? timestamp : nil, vobu.pci, vobu.dsi))
						}
					}
				}
				return (domain, domainNav)
			}

			data[file] = VTS(uniqueKeysWithValues: vtsNav)
		}
	}
}

private extension DVDData.VOB {
	/// Executes VOB read operations.
	class Reader {
		private let fileReader: OpaquePointer

		init(_ file: DVDData.FileId, domain: DVDData.DomainId, reader: OpaquePointer) throws {
			let fileReader = DVDOpenFile(reader, file.rawValue, domain.rawValue)
			guard let fileReader = fileReader else { throw DVDReaderError.vobReadError }
			self.fileReader = fileReader
		}

		func readCell(startingAt sector: Int) -> VOBUSequence {
			return VOBUSequence(startingAt: sector, file: fileReader)
		}

		deinit {
			DVDCloseFile(fileReader)
		}

		/// A sequence of consecutive Video Object Units.
		struct VOBUSequence: Sequence, IteratorProtocol {
			private let fileReader: OpaquePointer
			var currentSector: Int?

			init(startingAt sector: Int, file reader: OpaquePointer) {
				currentSector = sector
				fileReader = reader
			}

			mutating func next() -> VOBU? {
				guard let currentSector = currentSector else { return nil }

				let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: Int(DVD_VIDEO_LB_LEN))
				defer { buffer.deallocate() }
				let successful = DVDReadBlocks(fileReader, Int32(currentSector), 1, buffer.baseAddress)
				guard successful == 1 else { return nil }

				let vobu = VOBU(data: buffer)
				guard let vobu = vobu else { return nil }

				let nextVobu = vobu.dsi.vobu_sri.next_vobu.bits(0...29)
				if nextVobu != SRI_END_OF_CELL {
					self.currentSector = currentSector + Int(nextVobu)
				} else {
					self.currentSector = nil
				}

				return vobu
			}
		}
	}
}

private extension DVDData.VOB.VOBU {
	/// Initialize by parsing the first sector of VOBU data, which should contain the NAV packet.
	init?(data: UnsafeMutableBufferPointer<UInt8>) {
		func packetLength(at position: Int) -> Int {
			var length = 0
			length |= Int(data[position + 4]) << 8
			length |= Int(data[position + 5])
			return length
		}

		var position = data.startIndex

		if data[position + 3] == 0xBA {
			// program stream pack header
			if data[position + 4].bit(6) {
				// MPEG-2
				let stuffing = data[position + 13].bits(0...2)
				position += 14 + Int(stuffing)
			} else {
				// MPEG-1
				position += 12
			}
		}
		if data[position + 3] == 0xBB {
			// program stream system header
			position += 6 + packetLength(at: position)
		}
		guard data[position...position + 3].elementsEqual([0, 0, 1, 0xBF]) else { return nil }
		// private stream 2 packet reached
		let length = packetLength(at: position)

		position += 6
		guard data[position] == 0 else { return nil }
		// NAV PCI packet reached
		var pci = pci_t()
		navRead_PCI(&pci, data.baseAddress?.advanced(by: position + 1))
		self.pci = pci
		position += length

		position += 6
		guard data[position] == 1 else { return nil }
		// NAV DSI packet reached
		var dsi = dsi_t()
		navRead_DSI(&dsi, data.baseAddress?.advanced(by: position + 1))
		self.dsi = dsi
	}
}


/* MARK: Extracting Properties */

private extension Dictionary where Key == DVDData.IFO.All.Key, Value == DVDData.IFO.All.Value {
	/// The number of Video Title Sets on the DVD.
	var vtsCount: Int {
		Int(self[.vmgi]?.pointee.vmgi_mat?.pointee.vmg_nr_of_title_sets ?? 0)
	}

	/// Information about all titles on the DVD.
	var titleInfo: UnsafeBufferPointer<title_info_t> {
		let titleTable = self[.vmgi]?.pointee.tt_srpt?.pointee
		let titleStart = titleTable?.title
		let titleCount = titleTable?.nr_of_srpts
		return UnsafeBufferPointer(start: titleStart, count: titleCount)
	}

	/// Cells within program chains within a title set domain that should be scanned for NAV packets.
	func vtsNavCells(for key: Key) -> [DVDData.DomainId: [DVDData.PGCId: [cell_playback_t]]] {
		func firstPlayProgramChain() -> [DVDData.PGCId: [cell_playback_t]] {
			self[.vmgi]?.pointee.first_play_pgc.map { [.firstPlay: cells(within: $0.pointee)] } ?? [:]
		}

		func menuProgramChains(forKey key: Key) -> [DVDData.PGCId: [cell_playback_t]] {
			let languagesTable = self[key]?.pointee.pgci_ut?.pointee
			let languagesStart = languagesTable?.lu
			let languagesCount = languagesTable?.nr_of_lus
			let languages = UnsafeBufferPointer(start: languagesStart, count: languagesCount)
			let pgcs = languages.flatMap { language -> [(DVDData.PGCId, [cell_playback_t])] in
				let pgcInfosTable = language.pgcit?.pointee
				let pgcInfosStart = pgcInfosTable?.pgci_srp
				let pgcInfosCount = pgcInfosTable?.nr_of_pgci_srp
				let pgcInfos = UnsafeBufferPointer(start: pgcInfosStart, count: pgcInfosCount)
				return pgcInfos.compactMap { pgcInfo in
					let id = DVDData.PGCId.menu(language: language.lang_start_byte,
					                            pgc: pgcInfo.pgc_start_byte)
					return pgcInfo.pgc.map { (id, cells(within: $0.pointee)) } ?? nil
				}
			}
			return .init(uniqueKeysWithValues: pgcs)
		}

		func titleProgramChains(forIndex index: Int) -> [DVDData.PGCId: [cell_playback_t]] {
			let pgcInfosTable = self[.vtsi(index)]?.pointee.vts_pgcit?.pointee
			let pgcInfosStart = pgcInfosTable?.pgci_srp
			let pgcInfosCount = pgcInfosTable?.nr_of_pgci_srp
			let pgcInfos = UnsafeBufferPointer(start: pgcInfosStart, count: pgcInfosCount)
			let pgcs = pgcInfos.compactMap { pgcInfo -> (DVDData.PGCId, [cell_playback_t])? in
				let interactive = titleInfo.contains {
					// only include titles that contain interactive button commands
					$0.title_set_nr == index &&
					$0.vts_ttn == pgcInfo.entry_id.bits(0...6) &&
					$0.pb_ty.jlc_exists_in_button_cmd != 0
				}
				guard interactive else { return nil }
				let id = DVDData.PGCId.title(pgc: pgcInfo.pgc_start_byte)
				return pgcInfo.pgc.map { (id, cells(within: $0.pointee)) } ?? nil
			}
			return .init(uniqueKeysWithValues: pgcs)
		}

		func cells(within pgc: pgc_t) -> [cell_playback_t] {
			let cellsStart = pgc.cell_playback
			let cellsCount = pgc.nr_of_cells
			let cells = UnsafeBufferPointer(start: cellsStart, count: cellsCount)
			return Array(cells)
		}

		switch key {
		case .vmgi:
			return [
				.firstPlay: firstPlayProgramChain(),
				.menus: menuProgramChains(forKey: key)
			]
		case .vtsi(let index):
			return [
				.menus: menuProgramChains(forKey: key),
				.titles: titleProgramChains(forIndex: index)
			]
		}
	}
}

/// Error conditions while reading and understanding DVD information.
private enum DVDReaderError: String, Error {
	case vmgiReadError = "could not read VMGI"
	case vtsiReadError = "could not read VTSI"
	case vobReadError = "could not read VOB"
	case dataImportError = "DVD data not understood"
}

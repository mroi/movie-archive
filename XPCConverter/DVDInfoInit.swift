import MovieArchiveConverter
import LibDVDRead


/* MARK: Toplevel */

extension DVDInfo {
	init?(_ ifoData: DVDData.IFO.All) {
		guard let vmgi = ifoData[.vmgi]?.pointee else { return nil }
		guard let vmgiMat = vmgi.vmgi_mat?.pointee else { return nil }
		self.init(specification: Version(vmgiMat.specification_version),
		          category: vmgiMat.vmg_category,
		          provider: String(tuple: vmgiMat.provider_identifier),
		          posCode: vmgiMat.vmg_pos_code,
		          totalVolumeCount: vmgiMat.vmg_nr_of_volumes,
		          volumeIndex: vmgiMat.vmg_this_volume_nr,
		          discSide: vmgiMat.disc_side,
		          start: ProgramChain(vmgi.first_play_pgc?.pointee))
	}
}

private extension DVDInfo.Version {
	init(_ combined: UInt8) {
		self.init(major: combined.bits(4...7), minor: combined.bits(0...3))
	}
}

private extension DVDInfo.Time {
	init(_ time: dvd_time_t) {
		// dvd_time_t is in binary coded decimals
		func bcd(_ value: UInt8) -> UInt8 {
			value.bits(0...3) + 10 * value.bits(4...7)
		}
		self.init(hours: bcd(time.hour),
		          minutes: bcd(time.minute),
		          seconds: bcd(time.second),
		          frames: bcd(time.frame_u.bits(0...5)),
		          rate: FrameRate(time.frame_u))
	}
}

private extension DVDInfo.Time.FrameRate {
	init(_ frameInfo: UInt8) {
		switch frameInfo.bits(6...7) {
		case 1: self = .framesPerSecond(25.00)
		case 3: self = .framesPerSecond(29.97)
		default: self = .unexpected(frameInfo)
		}
	}
}


/* MARK: Program Chain */

private extension DVDInfo.ProgramChain {
	init(_ pgc: pgc_t) {
		let programsStart = pgc.program_map
		let programsCount = pgc.nr_of_programs
		let programsBuffer = UnsafeBufferPointer(start: programsStart, count: programsCount)
		let programs = Array(programsBuffer)

		let cellsStart = pgc.cell_playback
		let cellsCount = pgc.nr_of_cells
		let cellsBuffer = UnsafeBufferPointer(start: cellsStart, count: cellsCount)
		let cells = Array(cellsBuffer)

		let pre: [vm_cmd_t]
		let post: [vm_cmd_t]
		let cellPost: [vm_cmd_t]
		if let cmd = pgc.command_tbl?.pointee {
			let preStart = cmd.pre_cmds
			let preCount = cmd.nr_of_pre
			let preBuffer = UnsafeBufferPointer(start: preStart, count: preCount)
			pre = Array(preBuffer)
			let postStart = cmd.post_cmds
			let postCount = cmd.nr_of_post
			let postBuffer = UnsafeBufferPointer(start: postStart, count: postCount)
			post = Array(postBuffer)
			let cellStart = cmd.cell_cmds
			let cellCount = cmd.nr_of_cell
			let cellBuffer = UnsafeBufferPointer(start: cellStart, count: cellCount)
			cellPost = Array(cellBuffer)
		} else {
			pre = []; post = []; cellPost = []
		}

		self.init(programs: Dictionary(uniqueKeysWithValues: zip(1..., programs.map(Program.init))),
		          cells: Dictionary(uniqueKeysWithValues: zip(1..., cells.map(Cell.init))),
		          duration: DVDInfo.Time(pgc.playback_time),
		          playback: PlaybackMode(pgc.pg_playback_mode),
		          ending: EndingMode(pgc.still_time),
		          mapAudio: Dictionary(audio: pgc.audio_control),
		          mapSubpicture: Dictionary(subpicture: pgc.subp_control),
		          next: pgc.next_pgc_nr != 0 ? DVDInfo.Reference(programChain: .init(pgc.next_pgc_nr)) : nil,
		          previous: pgc.prev_pgc_nr != 0 ? DVDInfo.Reference(programChain: .init(pgc.prev_pgc_nr)) : nil,
		          up: pgc.goup_pgc_nr != 0 ? DVDInfo.Reference(programChain: .init(pgc.goup_pgc_nr)) : nil,
		          pre: Dictionary(uniqueKeysWithValues: zip(1..., pre.map(DVDInfo.Command.init))),
		          post: Dictionary(uniqueKeysWithValues: zip(1..., post.map(DVDInfo.Command.init))),
		          cellPost: Dictionary(uniqueKeysWithValues: zip(1..., cellPost.map(DVDInfo.Command.init))),
		          buttonPalette: Dictionary(palette: pgc.palette),
		          restrictions: DVDInfo.Restrictions(pgc.prohibited_ops))
	}
	init?(_ pgc: pgc_t?) {
		guard let pgc = pgc else { return nil }
		self.init(pgc)
	}
}

private extension DVDInfo.ProgramChain.Program {
	init(_ program: pgc_program_map_t) {
		self.init(start: DVDInfo.Reference(cell: .init(program)))
	}
}

private extension DVDInfo.ProgramChain.Cell {
	init(_ cell: cell_playback_t) {
		var playback = PlaybackMode()
		if cell.seamless_play != 0 { playback.update(with: .seamless) }
		if cell.interleaved != 0 { playback.update(with: .interleaved) }
		if cell.stc_discontinuity != 0 { playback.update(with: .timeDiscontinuity) }
		if cell.seamless_angle != 0 { playback.update(with: .seamlessAngle) }
		if cell.playback_mode != 0 { playback.update(with: .allStillFrames) }
		if cell.restricted != 0 { playback.update(with: .stopFastForward) }
		self.init(duration: DVDInfo.Time(cell.playback_time),
		          playback: playback,
		          ending: EndingMode(cell.still_time),
		          angle: AngleInfo(block: cell.block_type, cell: cell.block_mode),
		          karaoke: KaraokeInfo(cell.cell_type),
		          post: cell.cell_cmd_nr != 0 ? DVDInfo.Reference(command: .init(cell.cell_cmd_nr)) : nil,
		          sectors: DVDInfo.Index<DVDInfo.Sector>(cell.first_sector)...DVDInfo.Index<DVDInfo.Sector>(cell.last_sector))
	}
}

private extension DVDInfo.ProgramChain.Cell.AngleInfo {
	init?(block: UInt32, cell: UInt32) {
		if block == 0 && cell == 0 {
			return nil
		} else if block == 1 {
			switch cell {
			case 0: self = .externalCell
			case 1: self = .firstCellInBlock
			case 2: self = .innerCellInBlock
			case 3: self = .lastCellInBlock
			default: fatalError("illegal value \(cell)")
			}
		} else {
			self = .unexpected(block)
		}
	}
}

private extension DVDInfo.ProgramChain.Cell.KaraokeInfo {
	init?(_ cellType: UInt32) {
		switch cellType {
		case 0: return nil
		case 1: self = .titlePicture
		case 2: self = .introduction
		case 3: self = .bridge
		case 4: self = .firstClimax
		case 5: self = .secondClimax
		case 6: self = .maleVocal
		case 7: self = .femaleVocal
		case 8: self = .mixedVocal
		case 9: self = .interlude
		case 10: self = .interludeFadeIn
		case 11: self = .interludeFadeOut
		case 12: self = .firstEnding
		case 13: self = .secondEnding
		default: self = .unexpected(cellType)
		}
	}
}

private extension DVDInfo.ProgramChain.PlaybackMode {
	init(_ playbackMode: UInt8) {
		if playbackMode == 0 {
			self = .sequential
		} else if playbackMode.bit(7) {
			self = .random(programCount: playbackMode.bits(0...6) + 1)
		} else {
			self = .shuffle(programCount: playbackMode.bits(0...6) + 1)
		}
	}
}

private extension DVDInfo.ProgramChain.EndingMode {
	init(_ still: UInt8) {
		switch still {
		case UInt8.min: self = .immediate
		case UInt8.max: self = .holdLastFrameIndefinitely
		default: self = .holdLastFrame(seconds: still)
		}
	}
}

private extension Dictionary where Key == DVDInfo.Index<DVDInfo.LogicalAudioStream>, Value == DVDInfo.Index<DVDInfo.VOBAudioStream> {
	init(audio: (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16)) {
		self.init()
		let elements = Array<UInt16>(tuple: audio)
		for (index, stream) in zip(0..., elements) where stream.bit(15) {
			self[Key(index)] = Value(stream.bits(8...10))
		}
	}
}

private extension Dictionary where Key == DVDInfo.Index<DVDInfo.LogicalSubpictureStream>, Value == [DVDInfo.ProgramChain.SubpictureDescriptor: DVDInfo.Index<DVDInfo.VOBSubpictureStream>] {
	init(subpicture: (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
	                  UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
	                  UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
	                  UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32)) {
		self.init()
		let elements = Array<UInt32>(tuple: subpicture)
		for (index, stream) in zip(0..., elements) where stream.bit(31) {
			self[Key(index)] = [
				.classic:   DVDInfo.Index(stream.bits(24...28)),
				.wide:      DVDInfo.Index(stream.bits(16...20)),
				.letterbox: DVDInfo.Index(stream.bits(8...12)),
				.panScan:   DVDInfo.Index(stream.bits(0...4))
			]
		}
	}
}

private extension Dictionary where Key == DVDInfo.Index<Value>, Value == DVDInfo.ProgramChain.Color {
	init(palette: (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
	               UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32)) {
		let elements = Array<UInt32>(tuple: palette)
		self.init(minimumCapacity: elements.count)
		for (index, color) in zip(0..., elements) {
			self[Key(index)] = Value(color)
		}
	}
}

private extension DVDInfo.ProgramChain.Color {
	init(_ color: UInt32) {
		self.init(Y: UInt8(color.bits(16...23)),
		          Cb: UInt8(color.bits(8...15)),
		          Cr: UInt8(color.bits(0...7)))
	}
}


/* MARK: Command */

private extension DVDInfo.Command {
	init(_ command: vm_cmd_t) {
		var combined: UInt64 = 0
		combined |= UInt64(command.bytes.0) << 56
		combined |= UInt64(command.bytes.1) << 48
		combined |= UInt64(command.bytes.2) << 40
		combined |= UInt64(command.bytes.3) << 32
		combined |= UInt64(command.bytes.4) << 24
		combined |= UInt64(command.bytes.5) << 16
		combined |= UInt64(command.bytes.6) <<  8
		combined |= UInt64(command.bytes.7) <<  0
		let command = combined

		// TODO: decode command
		self = .unexpected(command)
	}
}


/* MARK: Restrictions */

private extension DVDInfo.Restrictions {
	init(_ ops: user_ops_t) {
		self.init()
		if ops.title_or_time_play != 0 { self.update(with: .noJumpIntoTitle) }
		if ops.chapter_search_or_play != 0 { self.update(with: .noJumpToPart) }
		if ops.title_play != 0 { self.update(with: .noJumpToTitle) }
		if ops.stop != 0 { self.update(with: .noStop) }
		if ops.go_up != 0 { self.update(with: .noJumpUp) }
		if ops.time_or_chapter_search != 0 { self.update(with: .noJumpIntoPart) }
		if ops.prev_or_top_pg_search != 0 { self.update(with: .noProgramBackward) }
		if ops.next_pg_search != 0 { self.update(with: .noProgramForward) }
		if ops.forward_scan != 0 { self.update(with: .noSeekForward) }
		if ops.backward_scan != 0 { self.update(with: .noSeekBackward) }
		if ops.title_menu_call != 0 { self.update(with: .noJumpToTopLevelMenu) }
		if ops.root_menu_call != 0 { self.update(with: .noJumpToPerTitleMenu) }
		if ops.subpic_menu_call != 0 { self.update(with: .noJumpToSubpictureMenu) }
		if ops.audio_menu_call != 0 { self.update(with: .noJumpToAudioMenu) }
		if ops.angle_menu_call != 0 { self.update(with: .noJumpToViewingAngleMenu) }
		if ops.chapter_menu_call != 0 { self.update(with: .noJumpToChapterMenu) }
		if ops.resume != 0 { self.update(with: .noResumeFromMenu) }
		if ops.button_select_or_activate != 0 { self.update(with: .noMenuInteractions) }
		if ops.still_off != 0 { self.update(with: .noStillSkip) }
		if ops.pause_on != 0 { self.update(with: .noPause) }
		if ops.audio_stream_change != 0 { self.update(with: .noChangeAudioStream) }
		if ops.subpic_stream_change != 0 { self.update(with: .noChangeSubpictureStream) }
		if ops.angle_change != 0 { self.update(with: .noChangeViewingAngle) }
		if ops.karaoke_audio_pres_mode_change != 0 { self.update(with: .noChangeKaraokeMode) }
		if ops.video_pres_mode_change != 0 { self.update(with: .noChangeVideoMode) }
	}
}

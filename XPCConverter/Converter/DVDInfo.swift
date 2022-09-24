/* MARK: DVDInfo */

/// Static information about the navigational and playback structure of the DVD.
public struct DVDInfo: Codable, Sendable {

	public let specification: Version
	public let category: UInt32
	public let discId: [UInt8]

	public let provider: String
	public let posCode: UInt64
	public let totalVolumeCount: UInt16
	public let volumeIndex: UInt16
	public let discSide: UInt8

	public let start: ProgramChain?
	public let topLevelMenus: Domain
	public let titleSets: [Index<TitleSet>: TitleSet]

	public init(specification: Version,
	            category: UInt32,
	            discId: [UInt8],
	            provider: String,
	            posCode: UInt64,
	            totalVolumeCount: UInt16,
	            volumeIndex: UInt16,
	            discSide: UInt8,
	            start: ProgramChain?,
	            topLevelMenus: Domain,
	            titleSets: [Index<TitleSet>: TitleSet]) {
		self.specification = specification
		self.category = category
		self.discId = discId
		self.provider = provider
		self.posCode = posCode
		self.totalVolumeCount = totalVolumeCount
		self.volumeIndex = volumeIndex
		self.discSide = discSide
		self.start = start
		self.topLevelMenus = topLevelMenus
		self.titleSets = titleSets
	}

	public struct Version: Codable, Sendable {
		public let major: UInt8
		public let minor: UInt8

		public init(major: UInt8, minor: UInt8) {
			self.major = major
			self.minor = minor
		}
	}

	public struct Time: Codable, Hashable, Sendable {
		public let hours: UInt8
		public let minutes: UInt8
		public let seconds: UInt8
		public let frames: UInt8
		public let rate: FrameRate
		public init(hours: UInt8,
		            minutes: UInt8,
		            seconds: UInt8,
		            frames: UInt8,
		            rate: FrameRate) {
			self.hours = hours
			self.minutes = minutes
			self.seconds = seconds
			self.frames = frames
			self.rate = rate
		}
		public enum FrameRate: Codable, Hashable, Sendable {
			case framesPerSecond(Double), unexpected(UInt8)
		}
	}

	public enum LogicalAudioStream {}
	public enum LogicalSubpictureStream {}
	public enum VOBAudioStream {}
	public enum VOBSubpictureStream {}
	public enum Sector {}

	/// Title sets form the navigational structure of the DVD.
	///
	/// A DVD is organized in title sets, which contain menus and playable
	/// content with common attributes, grouped in one menu and one title domain.
	public struct TitleSet: Codable, Sendable {
		public let titles: [Index<Title>: Title]
		public let menus: Domain
		public let content: Domain

		public let specification: Version
		public let category: UInt32

		public init(titles: [Index<Title>: Title],
		            menus: Domain,
		            content: Domain,
		            specification: Version,
		            category: UInt32) {
			self.titles = titles
			self.menus = menus
			self.content = content
			self.specification = specification
			self.category = category
		}

		/// Each title is presented to the user as one playable item.
		public struct Title: Codable, Sendable {
			public let globalIndex: Index<AllTitles>

			public let parts: [Index<Part>: Part]
			public let viewingAngleCount: UInt8

			public let jumpCommands: CommandPresence
			public let linearPlayback: Bool
			public let restrictions: Restrictions

			public init(globalIndex: Index<AllTitles>,
			            parts: [Index<Part>: Part],
			            viewingAngleCount: UInt8,
			            jumpCommands: CommandPresence,
			            linearPlayback: Bool,
			            restrictions: Restrictions) {
				self.globalIndex = globalIndex
				self.parts = parts
				self.viewingAngleCount = viewingAngleCount
				self.jumpCommands = jumpCommands
				self.linearPlayback = linearPlayback
				self.restrictions = restrictions
			}

			public enum AllTitles {}

			/// Parts are presented to the user as chapters within a title.
			public struct Part: Codable, Sendable {
				public let start: Reference<TitleSet, ProgramChain.Program>
				public init(start: Reference<TitleSet, ProgramChain.Program>) {
					self.start = start
				}
			}

			public struct CommandPresence: Codable, OptionSet, Sendable {
				public let rawValue: UInt8
				public static let features = CommandPresence(rawValue: 1 << 0)
				public static let prePosts = CommandPresence(rawValue: 1 << 1)
				public static let cells = CommandPresence(rawValue: 1 << 2)
				public static let buttons = CommandPresence(rawValue: 1 << 3)
				public init(rawValue: UInt8) { self.rawValue = rawValue }
			}
		}
	}

	/// Domains group a set of program chains with common attributes.
	///
	/// Three kinds of domains exist on DVDs:
	/// * Video Manager Menu (VMGM): top-level menu domain occurring once per DVD.
	/// * Video Title Set Menu (VTSM): menu domain within each title set.
	/// * Video Title Set (VTS): domain for playable content backing the titles.
	public struct Domain: Codable, Sendable {
		public let programChains: ProgramChains

		public let video: VideoAttributes
		public let audio: [Index<LogicalAudioStream>: AudioAttributes]
		public let subpicture: [Index<LogicalSubpictureStream>: SubpictureAttributes]

		public init(programChains: ProgramChains,
		            video: VideoAttributes,
		            audio: [Index<LogicalAudioStream>: AudioAttributes],
		            subpicture: [Index<LogicalSubpictureStream>: SubpictureAttributes]) {
			self.programChains = programChains
			self.video = video
			self.audio = audio
			self.subpicture = subpicture
		}

		/// Program chains for this domain.
		///
		/// The program chains within a domain are addressed by a descriptor,
		/// which uses different information for menu and title domains.
		/// The same program chain can be associated with multiple descriptors.
		///
		/// - Remark: Convenience accessor and subscript implementations are available.
		public struct ProgramChains: Codable, Sendable {
			private let mapping: [Descriptor: Id]
			private let storage: [Id: ProgramChain]

			public init(mapping: [Descriptor: Id], storage: [Id: ProgramChain]) {
				self.mapping = mapping
				self.storage = storage
			}

			public enum Descriptor: Codable, Hashable, Sendable {
				case menu(language: String, index: Index<ProgramChain>, entryPoint: Bool, type: MenuType?)
				case title(index: Index<ProgramChain>, entryPoint: Bool, title: Index<DVDInfo.TitleSet.Title>)
				public enum MenuType: Codable, Hashable, Sendable {
					case titles, rootWithinTitle, chapter
					case audio, subpicture, viewingAngle
					case unexpected(UInt8)
				}
			}
			public struct Id: Codable, Hashable, Sendable {
				public let languageId: UInt32?
				public let programChainId: UInt32
				public init(languageId: UInt32? = nil, programChainId: UInt32) {
					self.languageId = languageId
					self.programChainId = programChainId
				}
			}
		}

		public struct VideoAttributes: Codable, Sendable {
			public let coding: CodingType
			public let standard: VideoStandard
			public let codedPicture: Resolution
			public let displayAspect: AspectRatio
			public let allowedDisplay: DisplayModification
			public let line21cc: Line21ClosedCaption
			public let content: ContentInfo

			public init(coding: CodingType,
			            standard: VideoStandard,
			            codedPicture: Resolution,
			            displayAspect: AspectRatio,
			            allowedDisplay: DisplayModification,
			            line21cc: Line21ClosedCaption,
			            content: ContentInfo) {
				self.coding = coding
				self.standard = standard
				self.codedPicture = codedPicture
				self.displayAspect = displayAspect
				self.allowedDisplay = allowedDisplay
				self.line21cc = line21cc
				self.content = content
			}

			public enum CodingType: Codable, Sendable {
				case mpeg1, mpeg2, unexpected(UInt8)
			}
			public enum VideoStandard: Codable, Sendable {
				case ntsc, pal, unexpected(UInt8)
			}
			public struct Resolution: Codable, Sendable {
				public let width: UInt16?
				public let height: UInt16?
				public init(width: UInt16?, height: UInt16?) {
					self.width = width
					self.height = height
				}
			}
			public enum AspectRatio: Codable, Sendable {
				case classic(letterboxed: Bool), wide, unspecified, unexpected(UInt8)
			}
			public struct DisplayModification: Codable, OptionSet, Sendable {
				public let rawValue: UInt8
				public static let letterbox = DisplayModification(rawValue: 1 << 0)
				public static let panScan = DisplayModification(rawValue: 1 << 1)
				public init(rawValue: UInt8) { self.rawValue = rawValue }
			}
			public struct Line21ClosedCaption: Codable, OptionSet, Sendable {
				public let rawValue: UInt8
				public static let firstField = Line21ClosedCaption(rawValue: 1 << 0)
				public static let secondField = Line21ClosedCaption(rawValue: 1 << 1)
				public init(rawValue: UInt8) { self.rawValue = rawValue }
			}
			public enum ContentInfo: Codable, Sendable {
				case video, film
			}
		}

		public struct AudioAttributes: Codable, Sendable {
			public let coding: CodingType
			public let sampleFrequency: UInt32
			public let channelCount: UInt8
			public let rendering: RenderingIntent
			public let language: String?
			public let content: ContentInfo

			public init(coding: CodingType,
			            sampleFrequency: UInt32,
			            channelCount: UInt8,
			            rendering: RenderingIntent,
			            language: String?,
			            content: ContentInfo) {
				self.coding = coding
				self.sampleFrequency = sampleFrequency
				self.channelCount = channelCount
				self.rendering = rendering
				self.language = language
				self.content = content
			}

			public enum CodingType: Codable, Sendable {
				case ac3, dts
				case mpeg1(dynamicRangeCompression: Bool)
				case mpeg2(dynamicRangeCompression: Bool)
				case lpcm(bitsPerSample: UInt8)
				case unexpected(UInt8, UInt8)
			}
			public enum RenderingIntent: Codable, Sendable {
				case normal
				case surround(dolbyMatrixEncoded: Bool)
				case karaoke(version: UInt8, mode: Karaoke.Mode, channels: [Karaoke.Channel], multiChannelIntro: Bool)
				case unexpected(UInt8)
				public enum Karaoke {
					public enum Mode: Codable, Sendable {
						case solo, duet
					}
					public enum Channel: Codable, Sendable {
						case left, right, center, surround
						case guideMelody(String? = nil)
						case guideVocal(String? = nil)
						case effect(String? = nil)
					}
				}
			}
			public enum ContentInfo: Codable, Sendable {
				case sourceAudio, audioDescription, commentary, alternateCommentary
				case unspecified, unexpected(UInt8)
			}
		}

		public struct SubpictureAttributes: Codable, Sendable {
			public let coding: CodingType
			public let language: String?
			public let content: ContentInfo

			public init(coding: CodingType,
			            language: String?,
			            content: ContentInfo) {
				self.coding = coding
				self.language = language
				self.content = content
			}

			public enum CodingType: Codable, Sendable {
				case rle, extended, unexpected(UInt8)
			}
			public enum ContentInfo: Codable, Sendable {
				case subtitles(fontSize: FontSize, forChildren: Bool)
				case closedCaptions(fontSize: FontSize, forChildren: Bool)
				case commentary(fontSize: FontSize, forChildren: Bool)
				case forced, unspecified, unexpected(UInt8)
				public enum FontSize: Codable, Sendable {
					case normal, large
				}
			}
		}
	}

	/// Program chains form the playback structure of the DVD.
	///
	/// A program chain is a linearly playable (except for special cases) stream.
	/// DVD virtual machine commands can be executed at the beginning and end of
	/// the whole program chain or at the end of a cell. Links to a `next` and
	/// `previous` program chain continue playback beyond the end of the current
	/// chain. Navigating `up` allows for a hierarchical structure.
	public struct ProgramChain: Codable, Sendable {
		public let programs: [Index<Program>: Program]
		public let cells: [Index<Cell>: Cell]

		public let duration: Time
		public let playback: PlaybackMode
		public let ending: EndingMode
		public let mapAudio: [Index<LogicalAudioStream>: Index<VOBAudioStream>]
		public let mapSubpicture: [Index<LogicalSubpictureStream>: [SubpictureDescriptor: Index<VOBSubpictureStream>]]

		public let next: Reference<Domain, Self>?
		public let previous: Reference<Domain, Self>?
		public let up: Reference<Domain, Self>?

		public let pre: [Index<Command>: Command]
		public let post: [Index<Command>: Command]
		public let cellPost: [Index<Command>: Command]
		public let buttonPalette: [Index<Color>: Color]
		public let restrictions: Restrictions

		public init(programs: [Index<Program>: Program],
		            cells: [Index<Cell>: Cell],
		            duration: Time,
		            playback: PlaybackMode,
		            ending: EndingMode,
		            mapAudio: [Index<LogicalAudioStream>: Index<VOBAudioStream>],
		            mapSubpicture: [Index<LogicalSubpictureStream>: [SubpictureDescriptor: Index<VOBSubpictureStream>]],
		            next: Reference<Domain, Self>?,
		            previous: Reference<Domain, Self>?,
		            up: Reference<Domain, Self>?,
		            pre: [Index<Command>: Command],
		            post: [Index<Command>: Command],
		            cellPost: [Index<Command>: Command],
		            buttonPalette: [Index<Color>: Color],
		            restrictions: Restrictions) {
			self.programs = programs
			self.cells = cells
			self.duration = duration
			self.playback = playback
			self.ending = ending
			self.mapAudio = mapAudio
			self.mapSubpicture = mapSubpicture
			self.next = next
			self.previous = previous
			self.up = up
			self.pre = pre
			self.post = post
			self.cellPost = cellPost
			self.buttonPalette = buttonPalette
			self.restrictions = restrictions
		}

		/// Programs are the targets when the user skips forward or backward.
		public struct Program: Codable, Sendable {
			public let start: Reference<ProgramChain, Cell>
			public init(start: Reference<ProgramChain, Cell>) {
				self.start = start
			}
		}

		/// Cells subdivide programs for fine-grained programmatic interaction.
		public struct Cell: Codable, Sendable {
			public let duration: Time
			public let playback: PlaybackMode
			public let ending: EndingMode
			public let angle: AngleInfo?
			public let karaoke: KaraokeInfo?

			public let interaction: [Interaction]
			public let post: Reference<ProgramChain, Command>?
			public let sectors: ClosedRange<Index<Sector>>

			public init(duration: Time,
			            playback: PlaybackMode,
			            ending: EndingMode,
			            angle: AngleInfo?,
			            karaoke: KaraokeInfo?,
			            interaction: [Interaction],
			            post: Reference<ProgramChain, Command>?,
			            sectors: ClosedRange<Index<Sector>>) {
				self.duration = duration
				self.playback = playback
				self.ending = ending
				self.angle = angle
				self.karaoke = karaoke
				self.interaction = interaction
				self.post = post
				self.sectors = sectors
			}

			public struct PlaybackMode: Codable, OptionSet, Sendable {
				public let rawValue: UInt8
				public static let seamless = PlaybackMode(rawValue: 1 << 0)
				public static let seamlessAngle = PlaybackMode(rawValue: 1 << 1)
				public static let interleaved = PlaybackMode(rawValue: 1 << 2)
				public static let timeDiscontinuity = PlaybackMode(rawValue: 1 << 3)
				public static let allStillFrames = PlaybackMode(rawValue: 1 << 4)
				public static let stopFastForward = PlaybackMode(rawValue: 1 << 5)
				public init(rawValue: UInt8) { self.rawValue = rawValue }

			}
			public typealias EndingMode = ProgramChain.EndingMode
			public enum AngleInfo: Codable, Sendable {
				case firstCellInBlock
				case innerCellInBlock
				case lastCellInBlock
				case externalCell
				case unexpected(UInt32)
			}
			public enum KaraokeInfo: Codable, Sendable {
				case titlePicture, introduction, bridge
				case maleVocal, femaleVocal, mixedVocal
				case interludeFadeIn, interlude, interludeFadeOut
				case firstClimax, secondClimax
				case firstEnding, secondEnding
				case unexpected(UInt32)
			}
		}

		public enum PlaybackMode: Codable, Sendable {
			case sequential
			case random(programCount: UInt8)
			case shuffle(programCount: UInt8)
		}

		public enum EndingMode: Codable, Sendable {
			case immediate
			case holdLastFrame(seconds: UInt8)
			case holdLastFrameIndefinitely
		}

		public enum SubpictureDescriptor: Codable, Sendable {
			case classic, wide, letterbox, panScan
		}

		public struct Color: Codable, Sendable {
			public let Y, Cb, Cr: UInt8
			public init(Y: UInt8, Cb: UInt8, Cr: UInt8) {
				self.Y = Y
				self.Cb = Cb
				self.Cr = Cr
			}
		}
	}

	/// User interaction is defined by menu buttons with associated commands.
	public struct Interaction: Codable, Sendable {
		public let sector: Index<Sector>
		public let linearPlaybackTimestamp: Time?
		public let onlyCommandsChanged: Bool

		public let buttons: [Index<Button>: [ButtonDescriptor: Button]]
		public let buttonsSelectable: Time
		public let buttonsVisible: Time
		public let forcedSelect: Index<Button>?
		public let forcedAction: Index<Button>?

		public let restrictions: Restrictions

		public init(sector: Index<Sector>,
		            linearPlaybackTimestamp: Time?,
		            onlyCommandsChanged: Bool,
		            buttons: [Index<Button>: [ButtonDescriptor: Button]],
		            buttonsSelectable: Time,
		            buttonsVisible: Time,
		            forcedSelect: Index<Button>?,
		            forcedAction: Index<Button>?,
		            restrictions: Restrictions) {
			self.sector = sector
			self.linearPlaybackTimestamp = linearPlaybackTimestamp
			self.onlyCommandsChanged = onlyCommandsChanged
			self.buttons = buttons
			self.buttonsSelectable = buttonsSelectable
			self.buttonsVisible = buttonsVisible
			self.forcedSelect = forcedSelect
			self.forcedAction = forcedAction
			self.restrictions = restrictions
		}

		public struct ButtonDescriptor: Codable, Hashable, OptionSet, Sendable {
			public let rawValue: UInt32
			public static let classic = ButtonDescriptor([])
			public static let wide = ButtonDescriptor(rawValue: 1 << 0)
			public static let letterbox = ButtonDescriptor(rawValue: 1 << 1)
			public static let panScan = ButtonDescriptor(rawValue: 1 << 2)
			public init(rawValue: UInt32) { self.rawValue = rawValue }
		}

		public struct Button: Codable, Sendable {
			public let mask: Rectangle
			public let up: Reference<Interaction, Button>?
			public let down: Reference<Interaction, Button>?
			public let left: Reference<Interaction, Button>?
			public let right: Reference<Interaction, Button>?

			public let selectionColors: [Color]?
			public let actionColors: [Color]?

			public let action: Command
			public let autoActionOnSelect: Bool

			public init(mask: Rectangle,
			            up: Reference<Interaction, Button>?,
			            down: Reference<Interaction, Button>?,
			            left: Reference<Interaction, Button>?,
			            right: Reference<Interaction, Button>?,
			            selectionColors: [Color]?,
			            actionColors: [Color]?,
			            action: Command,
			            autoActionOnSelect: Bool) {
				self.mask = mask
				self.up = up
				self.down = down
				self.left = left
				self.right = right
				self.selectionColors = selectionColors
				self.actionColors = actionColors
				self.action = action
				self.autoActionOnSelect = autoActionOnSelect
			}

			public struct Rectangle: Codable, Sendable {
				public let xStart, xEnd, yStart, yEnd: UInt32
				public init(xStart: UInt32, xEnd: UInt32,
				            yStart: UInt32, yEnd: UInt32) {
					self.xStart = xStart
					self.xEnd = xEnd
					self.yStart = yStart
					self.yEnd = yEnd
				}
			}

			public struct Color: Codable, Sendable {
				public let color: Reference<ProgramChain, ProgramChain.Color>
				public let alpha: Double
				public init(color: DVDInfo.Reference<ProgramChain, ProgramChain.Color>,
				            alpha: Double) {
					self.color = color
					self.alpha = alpha
				}
			}
		}
	}

	/// Commands are executed by the DVD virtual machine.
	public indirect enum Command: Codable, Sendable {
		/// Perform a computate operation.
		case compute(Operation)

		/// Transition playback to a different position.
		case jump(to: Target)

		/// Transition playback to a different position, while remembering a resume point.
		case call(to: Target, resume: Index<ProgramChain.Cell>)

		/// Execute a command conditionally.
		case condition(if: Condition, then: Command)

		/// Compound commands consist of two individual commands.
		case compound(Command, Command)

		/// Set one or multiple system registers.
		case setSystemRegisters([SystemRegister: Operand])

		/// Set a general register counter mode and value
		case setGeneralRegister(Index<GeneralRegister>, counter: Bool, value: Operand)

		/// Temporary change of parental level.
		case setParentalLevelAndGoto(level: Int, line: Index<Command>)

		/// Jump to a different location within the current command list.
		case goto(line: Index<Command>)

		/// End the execution of the current command list.
		case `break`

		/// Terminate DVD playback.
		case exit

		/// Do nothing.
		case nop

		/// The command could not be parsed.
		case unexpected(UInt64)

		public enum Operation: Codable, Sendable {
			case assign(Operand, Operand)
			case swap(Operand, Operand)
			case add(Operand, Operand)
			case subtract(Operand, Operand)
			case multiply(Operand, Operand)
			case divide(Operand, Operand)
			case modulus(Operand, Operand)
			case random(Operand, Operand)
			case bitwiseAnd(Operand, Operand)
			case bitwiseOr(Operand, Operand)
			case bitwiseXor(Operand, Operand)
		}

		public enum Target: Codable, Sendable {
			case start
			case topLevelMenu(Domain.ProgramChains.Descriptor.MenuType)
			case topLevelProgramChain(Index<ProgramChain>)
			case titleMenu(Index<TitleSet>, Index<TitleSet.Title>, Domain.ProgramChains.Descriptor.MenuType)
			case title(Index<TitleSet.Title.AllTitles>)
			case titleWithinTitleSet(Index<TitleSet.Title>)
			case partWithinTitleSet(Index<TitleSet.Title>, Index<TitleSet.Title.Part>)
			case menu(Domain.ProgramChains.Descriptor.MenuType)
			case programChain(Index<ProgramChain>)
			case part(Index<TitleSet.Title.Part>, Index<Interaction.Button>)
			case program(Index<ProgramChain.Program>, Index<Interaction.Button>)
			case cell(Index<ProgramChain.Cell>, Index<Interaction.Button>)
			case startOfProgramChain(Index<Interaction.Button>)
			case nextProgramChain(Index<Interaction.Button>)
			case previousProgramChain(Index<Interaction.Button>)
			case upProgramChain(Index<Interaction.Button>)
			case endOfProgramChain(Index<Interaction.Button>)
			case startOfProgram(Index<Interaction.Button>)
			case nextProgram(Index<Interaction.Button>)
			case previousProgram(Index<Interaction.Button>)
			case startOfCell(Index<Interaction.Button>)
			case nextCell(Index<Interaction.Button>)
			case previousCell(Index<Interaction.Button>)
			case resume(Index<Interaction.Button>)
			case none(Index<Interaction.Button>)
		}

		public enum Condition: Codable, Sendable {
			case equal(Operand, Operand)
			case notEqual(Operand, Operand)
			case greaterThanOrEqual(Operand, Operand)
			case greaterThan(Operand, Operand)
			case lessThanOrEqual(Operand, Operand)
			case lessThan(Operand, Operand)
			case bitwiseAndNotZero(Operand, Operand)
		}

		public enum Operand: Codable, Hashable, Sendable {
			case immediate(UInt16)
			case generalRegister(Index<GeneralRegister>)
			case generalRegisterCounterMode(Index<GeneralRegister>)
			case systemRegister(SystemRegister)
		}

		public enum GeneralRegister {}

		public enum SystemRegister: Codable, Sendable {
			case audioStreamIndex
			case subpictureStreamIndex
			case viewingAngleIndex
			case globalTitleIndex
			case titleIndex
			case programChainIndex
			case partIndex
			case selectedButtonIndex
			case navigationTimer
			case programChainForTimer
			case videoMode
			case karaokeMode
			case preferredMenuLanguage
			case preferredAudioLanguage
			case preferredAudioContent
			case preferredSubpictureLanguage
			case preferredSubpictureContent
			case playerAudioCapabilities
			case playerRegionMask
			case parentalCountry
			case parentalLevel
			case reserved
			case unexpected
		}
	}

	/// Playback restrictions disable certain user interaction.
	public struct Restrictions: Codable, OptionSet, Sendable {
		public let rawValue: UInt32

		public static let noStop = Restrictions(rawValue: 1 << 3)
		public static let noJumpToTitle = Restrictions(rawValue: 1 << 2)
		public static let noJumpToPart = Restrictions(rawValue: 1 << 1)
		public static let noJumpIntoTitle = Restrictions(rawValue: 1 << 0)
		public static let noJumpIntoPart = Restrictions(rawValue: 1 << 5)
		public static let noJumpUp = Restrictions(rawValue: 1 << 4)

		public static let noJumpToTopLevelMenu = Restrictions(rawValue: 1 << 10)
		public static let noJumpToPerTitleMenu = Restrictions(rawValue: 1 << 11)
		public static let noJumpToAudioMenu = Restrictions(rawValue: 1 << 13)
		public static let noJumpToSubpictureMenu = Restrictions(rawValue: 1 << 12)
		public static let noJumpToViewingAngleMenu = Restrictions(rawValue: 1 << 14)
		public static let noJumpToChapterMenu = Restrictions(rawValue: 1 << 15)

		public static let noProgramForward = Restrictions(rawValue: 1 << 7)
		public static let noProgramBackward = Restrictions(rawValue: 1 << 6)
		public static let noSeekForward = Restrictions(rawValue: 1 << 8)
		public static let noSeekBackward = Restrictions(rawValue: 1 << 9)

		public static let noResumeFromMenu = Restrictions(rawValue: 1 << 16)
		public static let noMenuInteractions = Restrictions(rawValue: 1 << 17)
		public static let noStillSkip = Restrictions(rawValue: 1 << 18)
		public static let noPause = Restrictions(rawValue: 1 << 19)

		public static let noChangeAudioStream = Restrictions(rawValue: 1 << 20)
		public static let noChangeSubpictureStream = Restrictions(rawValue: 1 << 21)
		public static let noChangeViewingAngle = Restrictions(rawValue: 1 << 22)
		public static let noChangeVideoMode = Restrictions(rawValue: 1 << 24)
		public static let noChangeKaraokeMode = Restrictions(rawValue: 1 << 23)

		public init(rawValue: UInt32) { self.rawValue = rawValue }
	}

	/// Index type tightly coupled to the collection element it indexes.
	///
	/// The coupling ensures that different index types cannot be confused for one another.
	public struct Index<Element>: Codable, Hashable, Sendable, Strideable, ExpressibleByIntegerLiteral {
		public typealias IntegerLiteralType = UInt
		public typealias Stride = Int

		public let rawValue: UInt

		public init<T: UnsignedInteger>(_ rawValue: T) {
			self.rawValue = UInt(rawValue)
		}
		public init<T: SignedInteger>(_ rawValue: T) {
			guard rawValue >= 0 else { fatalError("index cannot be negative") }
			self.rawValue = UInt(rawValue)
		}
		public init(integerLiteral value: UInt) {
			self.rawValue = value
		}

		public func distance(to other: Self) -> Int {
			rawValue.distance(to: other.rawValue)
		}
		public func advanced(by n: Int) -> Self {
			Self.init(rawValue.advanced(by: n))
		}
	}

	/// Allows a property inside the `DVDInfo` structure to reference another.
	///
	/// - Remark: Subscript implementations are available to resolve references.
	public struct Reference<Root, Value>: Codable, Sendable {
		public let programChain: DVDInfo.Index<DVDInfo.ProgramChain>?
		public let program: DVDInfo.Index<DVDInfo.ProgramChain.Program>?
		public let cell: DVDInfo.Index<DVDInfo.ProgramChain.Cell>?
		public let command: DVDInfo.Index<DVDInfo.Command>?
		public let button: DVDInfo.Index<DVDInfo.Interaction.Button>?
		public let color: DVDInfo.Index<DVDInfo.ProgramChain.Color>?
	}
}


/* MARK: Custom Accessors */

extension DVDInfo.Domain.ProgramChains {
	public var descriptors: Dictionary<Descriptor, Id>.Keys { mapping.keys }
	public var all: Dictionary<Id, DVDInfo.ProgramChain>.Values { storage.values }

	public subscript(match predicate: (Descriptor) -> Bool) -> DVDInfo.ProgramChain? {
		let firstMatch = mapping.first { predicate($0.key) }
		guard let id = firstMatch?.value else { return nil }
		return storage[id]
	}
	public subscript(index: DVDInfo.Index<DVDInfo.ProgramChain>, language language: String? = nil) -> DVDInfo.ProgramChain? {
		let predicate = { (descriptor: Descriptor) -> Bool in
			switch descriptor {
			case .menu(language, index, _, _):
				return true
			case .title(index, _, _):
				return true
			default:
				return false
			}
		}
		return self[match: predicate]
	}
}

extension Dictionary<DVDInfo.Interaction.ButtonDescriptor, DVDInfo.Interaction.Button> {
	public subscript(match descriptor: Key) -> Value? {
		let selected = first { $0.key.contains(descriptor) }
		return selected?.value
	}
}


/* MARK: Reference */

extension DVDInfo.Reference<DVDInfo.TitleSet, DVDInfo.ProgramChain.Program> {
	public init(programChain: DVDInfo.Index<DVDInfo.ProgramChain>, program: DVDInfo.Index<Value>) {
		self.programChain = programChain
		self.program = program
		self.cell = nil
		self.command = nil
		self.button = nil
		self.color = nil
	}
}
extension DVDInfo.Reference<DVDInfo.Domain, DVDInfo.ProgramChain> {
	public init(programChain: DVDInfo.Index<Value>) {
		self.programChain = programChain
		self.program = nil
		self.cell = nil
		self.command = nil
		self.button = nil
		self.color = nil
	}
}
extension DVDInfo.Reference<DVDInfo.ProgramChain, DVDInfo.ProgramChain.Cell> {
	public init(cell: DVDInfo.Index<Value>) {
		self.programChain = nil
		self.program = nil
		self.cell = cell
		self.command = nil
		self.button = nil
		self.color = nil
	}
}
extension DVDInfo.Reference<DVDInfo.ProgramChain, DVDInfo.Command> {
	public init(command: DVDInfo.Index<Value>) {
		self.programChain = nil
		self.program = nil
		self.cell = nil
		self.command = command
		self.button = nil
		self.color = nil
	}
}
extension DVDInfo.Reference<DVDInfo.Interaction, DVDInfo.Interaction.Button> {
	public init(button: DVDInfo.Index<Value>) {
		self.programChain = nil
		self.program = nil
		self.cell = nil
		self.command = nil
		self.button = button
		self.color = nil
	}
}
extension DVDInfo.Reference<DVDInfo.ProgramChain, DVDInfo.ProgramChain.Color> {
	public init(color: DVDInfo.Index<Value>) {
		self.programChain = nil
		self.program = nil
		self.cell = nil
		self.command = nil
		self.button = nil
		self.color = color
	}
}

extension DVDInfo.TitleSet {
	public subscript(resolve reference: DVDInfo.Reference<Self, DVDInfo.ProgramChain.Program>) -> DVDInfo.ProgramChain.Program? {
		return content.programChains[reference.programChain!]?.programs[reference.program!]
	}
}
extension DVDInfo.Domain {
	public subscript(resolve reference: DVDInfo.Reference<Self, DVDInfo.ProgramChain>,
	                 language: String? = nil) -> DVDInfo.ProgramChain? {
		return programChains[reference.programChain!, language: language]
	}
}
extension DVDInfo.ProgramChain {
	public subscript(resolve reference: DVDInfo.Reference<Self, Cell>) -> Cell? {
		return cells[reference.cell!]
	}
	public subscript(resolve reference: DVDInfo.Reference<Self, DVDInfo.Command>) -> DVDInfo.Command? {
		return cellPost[reference.command!]
	}
	public subscript(resolve reference: DVDInfo.Reference<Self, Color>) -> Color? {
		return buttonPalette[reference.color!]
	}
}
extension DVDInfo.Interaction {
	public subscript(resolve reference: DVDInfo.Reference<Self, Button>,
	                 descriptor: ButtonDescriptor) -> Button? {
		return buttons[reference.button!]?[match: descriptor]
	}
}

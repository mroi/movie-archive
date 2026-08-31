import RegexBuilder
import MovieArchiveModel
import MovieArchiveConverter


/* MARK: DVDInfo Custom JSON */

extension DVDInfo: @retroactive CustomJSON.EmptyCollectionSkipping {}
extension DVDInfo.TitleSet: @retroactive CustomJSON.EmptyCollectionSkipping {}
extension DVDInfo.TitleSet.Title: @retroactive CustomJSON.EmptyCollectionSkipping {}
extension DVDInfo.Domain: @retroactive CustomJSON.EmptyCollectionSkipping {}
extension DVDInfo.ProgramChain: @retroactive CustomJSON.EmptyCollectionSkipping {}
extension DVDInfo.ProgramChain.Cell: @retroactive CustomJSON.EmptyCollectionSkipping {}
extension DVDInfo.Interaction: @retroactive CustomJSON.EmptyCollectionSkipping {}

extension DVDInfo.Domain.VideoAttributes.CodingType: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Domain.VideoAttributes.VideoStandard: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Domain.VideoAttributes.ContentInfo: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Domain.AudioAttributes.CodingType: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Domain.AudioAttributes.RenderingIntent: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Domain.AudioAttributes.RenderingIntent.Karaoke.Mode: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Domain.AudioAttributes.RenderingIntent.Karaoke.Channel: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Domain.AudioAttributes.ContentInfo: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Domain.SubpictureAttributes.CodingType: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Domain.SubpictureAttributes.ContentInfo: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Domain.SubpictureAttributes.ContentInfo.FontSize: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.ProgramChain.Cell.AngleInfo: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.ProgramChain.Cell.KaraokeInfo: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.ProgramChain.PlaybackMode: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.ProgramChain.EndingMode: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Command.Operation: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Command.Target: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Command.Condition: @retroactive CustomJSON.CompactEnum {}
extension DVDInfo.Command.Operand: @retroactive CustomJSON.CompactEnum {}

extension DVDInfo.TitleSet.Title.CommandPresence: @retroactive CustomJSON.OptionSetCoding {
	public var allValues: KeyValuePairs<String, Element> {
		[
			"features": .features,
			"prePosts": .prePosts,
			"cells": .cells,
			"buttons": .buttons
		]
	}
}

extension DVDInfo.Domain.ProgramChains.Descriptor: @retroactive CustomJSON.StringKeyRepresentable {
	public var stringValue: String {
		switch self {
		case .menu(language: let language, entryPoint: let entryPoint, type: let type, index: let index):
			return "menu(language: \(language), entryPoint: \(entryPoint)" +
				(type.map { ", type: \($0)" } ?? "") +
				", index: \(index))"
		case .title(title: let title, entryPoint: let entryPoint, index: let index):
			return "title(title: \(title), entryPoint: \(entryPoint), index: \(index))"
		}
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		switch (lhs, rhs) {
		case (.menu(language: let lhsLanguage, entryPoint: let lhsEntryPoint, type: let lhsType, index: let lhsIndex), .menu(language: let rhsLanguage, entryPoint: let rhsEntryPoint, type: let rhsType, index: let rhsIndex)) where lhsLanguage == rhsLanguage && lhsEntryPoint == rhsEntryPoint && lhsType == rhsType:
			return lhsIndex < rhsIndex
		case (.menu(language: let lhsLanguage, entryPoint: let lhsEntryPoint, type: .some(let lhsType), _), .menu(language: let rhsLanguage, entryPoint: let rhsEntryPoint, type: .some(let rhsType), _)) where lhsLanguage == rhsLanguage && lhsEntryPoint == rhsEntryPoint:
			return lhsType < rhsType
		case (.menu(language: let lhsLanguage, entryPoint: let lhsEntryPoint, type: .some, _), .menu(language: let rhsLanguage, entryPoint: let rhsEntryPoint, type: .none, _)) where lhsLanguage == rhsLanguage && lhsEntryPoint == rhsEntryPoint:
			return true
		case (.menu(language: let lhsLanguage, entryPoint: let lhsEntryPoint, type: .none, _), .menu(language: let rhsLanguage, entryPoint: let rhsEntryPoint, type: .some, _)) where lhsLanguage == rhsLanguage && lhsEntryPoint == rhsEntryPoint:
			return false
		case (.menu(language: let lhsLanguage, entryPoint: let lhsEntryPoint, _, _), .menu(language: let rhsLanguage, entryPoint: let rhsEntryPoint, _, _)) where lhsLanguage == rhsLanguage:
			return lhsEntryPoint && !rhsEntryPoint
		case (.menu(language: let lhsLanguage, _, _, _), .menu(language: let rhsLanguage, _, _, _)):
			return lhsLanguage < rhsLanguage
		case (.title(title: let lhsTitle, entryPoint: let lhsEntryPoint, index: let lhsIndex), .title(title: let rhsTitle, entryPoint: let rhsEntryPoint, index: let rhsIndex)) where lhsTitle == rhsTitle && lhsEntryPoint == rhsEntryPoint:
			return lhsIndex < rhsIndex
		case (.title(title: let lhsTitle, entryPoint: let lhsEntryPoint, _), .title(title: let rhsTitle, entryPoint: let rhsEntryPoint, _)) where lhsTitle == rhsTitle:
			return lhsEntryPoint && !rhsEntryPoint
		case (.title(title: let lhsTitle, _, _), .title(title: let rhsTitle, _, _)):
			return lhsTitle < rhsTitle
		case (.menu, .title):
			return true
		case (.title, .menu):
			return false
		}
	}

	public init?(stringValue: String) {
		func labeledArgument<Type>(_ label: String, as reference: Reference<Type>, transform: @escaping (Substring) -> Type) -> some RegexComponent {
			Regex {
				label
				ZeroOrMore(.whitespace)
				":"
				ZeroOrMore(.whitespace)
				TryCapture(as: reference, {
					ZeroOrMore(CharacterClass.any.subtracting(.anyOf(",)")).subtracting(.whitespace))
				}, transform: transform)
			}
		}
		func descriptor(for selector: String, using argument: some RegexComponent) -> some RegexComponent {
			Regex {
				selector
				"("
				ZeroOrMore {
					ZeroOrMore(.whitespace)
					argument
					ZeroOrMore(.whitespace)
					/(?:,(?!\s*\))|(?=\)))/   // match a comma unless it is followed by a closing parenthesis
				}
				")"
			}
		}

		switch stringValue {

		case let string where string.hasPrefix("menu"):
			let language = Reference(String?.self)
			let entryPoint = Reference(Bool?.self)
			let menuType = Reference(MenuType?.self)
			let index = Reference(DVDInfo.Index<DVDInfo.ProgramChain>?.self)
			let menuArguments = ChoiceOf {
				labeledArgument("language", as: language, transform: String.init)
				labeledArgument("entryPoint", as: entryPoint, transform: { Bool(String($0)) })
				labeledArgument("type", as: menuType, transform: { MenuType(stringValue: String($0)) })
				labeledArgument("index", as: index, transform: { UInt($0).map(DVDInfo.Index<DVDInfo.ProgramChain>.init) })
			}
			let arguments = string.wholeMatch(of: descriptor(for: "menu", using: menuArguments))
			guard let arguments else { return nil }
			guard arguments[language] != nil, arguments[entryPoint] != nil, arguments[index] != nil else { return nil }
			self = .menu(language: arguments[language]!, entryPoint: arguments[entryPoint]!, type: arguments[menuType], index: arguments[index]!)

		case let string where string.hasPrefix("title"):
			let title = Reference(DVDInfo.Index<DVDInfo.TitleSet.Title>?.self)
			let entryPoint = Reference(Bool?.self)
			let index = Reference(DVDInfo.Index<DVDInfo.ProgramChain>?.self)
			let titleArguments = ChoiceOf {
				labeledArgument("title", as: title, transform: { UInt($0).map(DVDInfo.Index<DVDInfo.TitleSet.Title>.init) })
				labeledArgument("entryPoint", as: entryPoint, transform: { Bool(String($0)) })
				labeledArgument("index", as: index, transform: { UInt($0).map(DVDInfo.Index<DVDInfo.ProgramChain>.init) })
			}
			let arguments = string.wholeMatch(of: descriptor(for: "title", using: titleArguments))
			guard let arguments else { return nil }
			guard arguments[title] != nil, arguments[entryPoint] != nil, arguments[index] != nil else { return nil }
			self = .title(title: arguments[title]!, entryPoint: arguments[entryPoint]!, index: arguments[index]!)

		default:
			return nil
		}
	}
}

extension DVDInfo.Domain.ProgramChains.Descriptor.MenuType: @retroactive CustomJSON.StringKeyRepresentable, @retroactive CustomJSON.Codable {
	public var stringValue: String { String(describing: self) }

	public static func < (lhs: Self, rhs: Self) -> Bool {
		func sortIndex(_ value: Self) -> Int {
			switch value {
			case .titles: 0
			case .rootWithinTitle: 1
			case .chapter: 2
			case .audio: 3
			case .subpicture: 4
			case .viewingAngle: 5
			case .unexpected(_): 6
			}
		}
		return sortIndex(lhs) < sortIndex(rhs)
	}

	public init?(stringValue: String) {
		switch stringValue {
		case "titles": self = .titles
		case "rootWithinTitle": self = .rootWithinTitle
		case "chapter": self = .chapter
		case "audio": self = .audio
		case "subpicture": self = .subpicture
		case "viewingAngle": self = .viewingAngle
		case let string where string.hasPrefix("unexpected"):
			let match = string.wholeMatch {
				"unexpected("
				TryCapture { OneOrMore(.digit) } transform: { UInt8($0) }
				")"
			}
			guard let match else { return nil }
			self = .unexpected(match.1)
		default: return nil
		}
	}
}

extension DVDInfo.Domain.ProgramChains.Id: @retroactive CustomJSON.StringKeyRepresentable, @retroactive CustomJSON.Codable {
	public var stringValue: String {
		(languageId.map { String($0) + ":" } ?? "") + String(programChainId)
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		switch (lhs.languageId, rhs.languageId) {
		case (.some(let lhs), .some(let rhs)) where lhs != rhs:
			lhs < rhs
		case (.some, .some):
			lhs.programChainId < rhs.programChainId
		case (.some, .none):
			true
		case (.none, .some):
			false
		case (.none, .none):
			lhs.programChainId < rhs.programChainId
		}
	}

	public init?(stringValue: String) {
		let components = stringValue.split(separator: ":")
		let ids = components.compactMap { UInt32($0) }
		guard components.count == ids.count else { return nil }
		switch ids.count {
		case 1:
			self.init(languageId: nil, programChainId: ids[0])
		case 2:
			self.init(languageId: ids[0], programChainId: ids[1])
		default: return nil
		}
	}
}

extension DVDInfo.Domain.VideoAttributes.AspectRatio: @retroactive CustomJSON.Codable {
	public func encode(toCustomJSON encoder: Encoder) throws {
		switch self {
		case .classic(letterboxed: let letterboxed):
			var container = encoder.singleValueContainer()
			try container.encode(letterboxed ? "letterboxed" : "classic")
		default:
			try encode(to: encoder)
			try encoder.compactifyEnum()
		}
	}

	public init(fromCustomJSON decoder: Decoder) throws {
		let container = try? decoder.singleValueContainer()
		let label = try? container?.decode(String.self)
		switch label {
		case "classic": self = .classic(letterboxed: false)
		case "letterboxed": self = .classic(letterboxed: true)
		default: try self.init(from: decoder.reconstructedEnum())
		}
	}
}

extension DVDInfo.Domain.VideoAttributes.DisplayModification: @retroactive CustomJSON.OptionSetCoding {
	public var allValues: KeyValuePairs<String, Element> {
		[
			"letterbox": .letterbox,
			"pan&scan": .panScan
		]
	}
}

extension DVDInfo.Domain.VideoAttributes.Line21ClosedCaption: @retroactive CustomJSON.OptionSetCoding {
	public var allValues: KeyValuePairs<String, Element> {
		[
			"firstField": .firstField,
			"secondField": .secondField
		]
	}
}

extension DVDInfo.ProgramChain.Cell.PlaybackMode: @retroactive CustomJSON.OptionSetCoding {
	public var allValues: KeyValuePairs<String, Element> {
		[
			"seamless": .seamless,
			"seamlessAngle": .seamlessAngle,
			"interleaved": .interleaved,
			"timeDiscontinuity": .timeDiscontinuity,
			"allStillFrames": .allStillFrames,
			"stopFastForward": .stopFastForward
		]
	}
}

extension DVDInfo.ProgramChain.SubpictureDescriptor: @retroactive CustomJSON.StringKeyRepresentable {
	public var stringValue: String { String(describing: self) }

	public static func < (lhs: Self, rhs: Self) -> Bool {
		func sortIndex(_ value: Self) -> Int {
			switch value {
			case .classic: 0
			case .wide: 1
			case .letterbox: 2
			case .panScan: 3
			}
		}
		return sortIndex(lhs) < sortIndex(rhs)
	}

	public init?(stringValue: String) {
		switch stringValue {
		case "classic": self = .classic
		case "wide": self = .wide
		case "letterbox": self = .letterbox
		case "panScan": self = .panScan
		default: return nil
		}
	}
}

extension DVDInfo.Interaction.ButtonDescriptor: @retroactive CustomJSON.StringKeyRepresentable {
	public var stringValue: String {
		var elements: [String] = []
		if rawValue == 0 { elements = ["classic"] }
		if contains(.wide) { elements.append("wide") }
		if contains(.letterbox) { elements.append("letterbox") }
		if contains(.panScan) { elements.append("panScan") }
		return elements.joined(separator: ", ")
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		return lhs.rawValue < rhs.rawValue
	}

	public init?(stringValue: String) {
		let elements = stringValue.split(separator: ",").map {
			$0.trimmingCharacters(in: .whitespaces)
		}
		self.init()
		for element in elements {
			switch element {
			case "classic": guard elements.count == 1 else { return nil	}
			case "wide": self.insert(.wide)
			case "letterbox": self.insert(.letterbox)
			case "panScan": self.insert(.panScan)
			default: return nil
			}
		}
	}
}

extension DVDInfo.Command: @retroactive CustomJSON.Codable {
	public func encode(toCustomJSON encoder: Encoder) throws {
		switch self {
		case .setSystemRegisters(let settings):
			var container = encoder.container(keyedBy: EnumKeys.self)
			try container.encode(settings, forKey: "setSystemRegisters")
		default:
			try encode(to: encoder)
			try encoder.compactifyEnum()
		}
	}

	public init(fromCustomJSON decoder: Decoder) throws {
		let container = try? decoder.container(keyedBy: EnumKeys.self)
		let label = try? container?.singleKey.stringValue
		switch label {
		case "setSystemRegisters":
			self = .setSystemRegisters(try container!.decode([SystemRegister: Operand].self))
		default: try self.init(from: decoder.reconstructedEnum())
		}
	}
}

extension DVDInfo.Command.SystemRegister: @retroactive CustomJSON.StringKeyRepresentable, @retroactive CustomJSON.Codable {
	public var stringValue: String { String(describing: self) }

	public static func < (lhs: Self, rhs: Self) -> Bool {
		func sortIndex(_ value: Self) -> Int {
			switch value {
			case .audioStreamIndex: 0
			case .subpictureStreamIndex: 1
			case .viewingAngleIndex: 2
			case .globalTitleIndex: 3
			case .titleIndex: 4
			case .programChainIndex: 5
			case .partIndex: 6
			case .selectedButtonIndex: 7
			case .navigationTimer: 8
			case .programChainForTimer: 9
			case .videoMode: 10
			case .karaokeMode: 11
			case .preferredMenuLanguage: 12
			case .preferredAudioLanguage: 13
			case .preferredAudioContent: 14
			case .preferredSubpictureLanguage: 15
			case .preferredSubpictureContent: 16
			case .playerAudioCapabilities: 17
			case .playerRegionMask: 18
			case .parentalCountry: 19
			case .parentalLevel: 20
			case .reserved: 21
			case .unexpected: 22
			}
		}
		return sortIndex(lhs) < sortIndex(rhs)
	}

	public init?(stringValue: String) {
		switch stringValue {
		case "audioStreamIndex": self = .audioStreamIndex
		case "subpictureStreamIndex": self = .subpictureStreamIndex
		case "viewingAngleIndex": self = .viewingAngleIndex
		case "globalTitleIndex": self = .globalTitleIndex
		case "titleIndex": self = .titleIndex
		case "programChainIndex": self = .programChainIndex
		case "partIndex": self = .partIndex
		case "selectedButtonIndex": self = .selectedButtonIndex
		case "navigationTimer": self = .navigationTimer
		case "programChainForTimer": self = .programChainForTimer
		case "videoMode": self = .videoMode
		case "karaokeMode": self = .karaokeMode
		case "preferredMenuLanguage": self = .preferredMenuLanguage
		case "preferredAudioLanguage": self = .preferredAudioLanguage
		case "preferredAudioContent": self = .preferredAudioContent
		case "preferredSubpictureLanguage": self = .preferredSubpictureLanguage
		case "preferredSubpictureContent": self = .preferredSubpictureContent
		case "playerAudioCapabilities": self = .playerAudioCapabilities
		case "playerRegionMask": self = .playerRegionMask
		case "parentalCountry": self = .parentalCountry
		case "parentalLevel": self = .parentalLevel
		case "reserved": self = .reserved
		case "unexpected": self = .unexpected
		default: return nil
		}
	}
}

extension DVDInfo.Restrictions: @retroactive CustomJSON.OptionSetCoding {
	public var allValues: KeyValuePairs<String, Self> {
		[
			"noStop": .noStop,
			"noJumpToTitle": .noJumpToTitle,
			"noJumpToPart": .noJumpToPart,
			"noJumpIntoTitle": .noJumpIntoTitle,
			"noJumpIntoPart": .noJumpIntoPart,
			"noJumpUp": .noJumpUp,
			"noJumpToTopLevelMenu": .noJumpToTopLevelMenu,
			"noJumpToPerTitleMenu": .noJumpToPerTitleMenu,
			"noJumpToAudioMenu": .noJumpToAudioMenu,
			"noJumpToSubpictureMenu": .noJumpToSubpictureMenu,
			"noJumpToViewingAngleMenu": .noJumpToViewingAngleMenu,
			"noJumpToChapterMenu": .noJumpToChapterMenu,
			"noProgramForward": .noProgramForward,
			"noProgramBackward": .noProgramBackward,
			"noSeekForward": .noSeekForward,
			"noSeekBackward": .noSeekBackward,
			"noResumeFromMenu": .noResumeFromMenu,
			"noMenuInteractions": .noMenuInteractions,
			"noStillSkip": .noStillSkip,
			"noPause": .noPause,
			"noChangeAudioStream": .noChangeAudioStream,
			"noChangeSubpictureStream": .noChangeSubpictureStream,
			"noChangeViewingAngle": .noChangeViewingAngle,
			"noChangeVideoMode": .noChangeVideoMode,
			"noChangeKaraokeMode": .noChangeKaraokeMode
		]
	}
}

extension DVDInfo.Index: @retroactive CustomJSON.StringKeyRepresentable, @retroactive CustomJSON.Codable {
	// custom encoding: directly use internal integer value
	public var stringValue: String { String(rawValue) }
	public init?(stringValue: String) {
		guard let uintValue = UInt(stringValue) else { return nil }
		self.init(uintValue)
	}
}

extension DVDInfo.Index: @retroactive CustomStringConvertible {
	public var description: String { rawValue.description }
}

extension DVDInfo.Time: @retroactive CustomJSON.Codable {
	// custom encoding: time as human-readable string

	public func encode(toCustomJSON encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		var string: String

		switch rate {
		case .framesPerSecond(let fps) where fps.rounded() == 25:
			string = "25"
		case .framesPerSecond(let fps) where fps.rounded() == 30:
			string = "30"
		case .framesPerSecond(let fps):
			if (hours, minutes, seconds, frames) == (0, 0, 0, 0) {
				string = "0"
			} else {
				throw EncodingError.invalidValue(fps, .init(codingPath: encoder.codingPath,
					debugDescription: "unsupported frame rate \(fps)"))
			}
		case .unexpected(let value):
			if (hours, minutes, seconds, frames) == (0, 0, 0, 0) {
				string = "0"
			} else {
				throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath,
					debugDescription: "unexpected frame rate value \(value)"))
			}
		}

		if hours != 0 || minutes != 0 || seconds != 0 {
			string = String(format: "%02d", frames) + "@" + string
			if hours != 0 || minutes != 0 {
				string = String(format: "%02d", seconds) + ":" + string
				if hours != 0 {
					string = String(format: "%02d", minutes) + ":" + string
					string = String(hours) + ":" + string
				} else {
					string = String(minutes) + ":" + string
				}
			} else {
				string = String(seconds) + ":" + string
			}
		} else {
			string = String(frames) + "@" + string
		}

		try container.encode(string)
	}

	public init(fromCustomJSON decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let string = try container.decode(String.self)

		let hours = Reference(UInt8?.self)
		let minutes = Reference(UInt8?.self)
		let seconds = Reference(UInt8?.self)
		let frames = Reference(UInt8.self)
		let rate = Reference(FrameRate.self)

		let components = string.wholeMatch {
			// broken out of the builder expression because the compiler is unable to typecheck
			let hoursPattern = TryCapture(as: hours) { OneOrMore(.digit) } transform: { UInt8($0) }
			Optionally {
				Optionally {
					Optionally {
						hoursPattern
						":"
					}
					TryCapture(as: minutes) { OneOrMore(.digit) } transform: { UInt8($0) }
					":"
				}
				TryCapture(as: seconds) { OneOrMore(.digit) } transform: { UInt8($0) }
				":"
			}
			TryCapture(as: frames) { OneOrMore(.digit) } transform: { UInt8($0) }
			"@"
			TryCapture(as: rate) {
				OneOrMore(.digit)
				Optionally {
					"."
					OneOrMore(.digit)
				}
			} transform: {
				guard let integer = UInt($0) else { return nil }
				let rate: Double = switch integer {
				case 25: 25.00
				case 30: 29.97
				default: Double($0) ?? Double(integer)
				}
				return .framesPerSecond(rate)
			}
		}
		guard let components else {
			throw DecodingError.dataCorruptedError(in: container,
				debugDescription: "malformed time: ‘\(string)’")
		}

		self.init(hours: components[hours] ?? 0,
		          minutes: components[minutes] ?? 0,
		          seconds: components[seconds] ?? 0,
		          frames: components[frames],
		          rate: components[rate])
	}
}

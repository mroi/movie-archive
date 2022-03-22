import MovieArchiveModel
import MovieArchiveConverter


/* MARK: DVDInfo Custom JSON */

extension DVDInfo: CustomJSONEmptyCollectionSkipping {}
extension DVDInfo.TitleSet: CustomJSONEmptyCollectionSkipping {}
extension DVDInfo.TitleSet.Title: CustomJSONEmptyCollectionSkipping {}
extension DVDInfo.Domain: CustomJSONEmptyCollectionSkipping {}
extension DVDInfo.ProgramChain: CustomJSONEmptyCollectionSkipping {}
extension DVDInfo.ProgramChain.Cell: CustomJSONEmptyCollectionSkipping {}
extension DVDInfo.Interaction: CustomJSONEmptyCollectionSkipping {}

extension DVDInfo.Domain.ProgramChains.Descriptor: CustomJSONStringKeyRepresentable {
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

	/// - ToDo: Simplify using `Regex` once we move to macOS 13
	public init?(stringValue: String) {
		func parseElements(_ tupleString: Substring) -> [String: String] {
			guard tupleString.hasPrefix("(") && tupleString.hasSuffix(")") else {
				return [:]
			}
			let elementsString = tupleString.dropFirst().dropLast()
			let elementsList = elementsString.split(separator: ",")
			let elementsPairs = elementsList.compactMap { element -> (String, String)? in
				let pair = element.split(separator: ":").map {
					$0.trimmingCharacters(in: .whitespaces)
				}
				guard pair.count == 2 else { return nil }
				return (pair[0], pair[1])
			}
			return Dictionary(uniqueKeysWithValues: elementsPairs)
		}

		switch stringValue {

		case let string where string.hasPrefix("menu"):
			let elements = parseElements(string.dropFirst("menu".count))
			guard let language = elements["language"] else { return nil }
			guard let element = elements["entryPoint"], let entryPoint = Bool(element) else { return nil }
			let type: MenuType?
			if let element = elements["type"] {
				guard let decoded = MenuType(stringValue: element) else { return nil }
				type = decoded
			} else {
				type = nil
			}
			guard let element = elements["index"], let index = UInt(element) else { return nil }
			self = .menu(language: language, entryPoint: entryPoint, type: type, index: .init(index))

		case let string where string.hasPrefix("title"):
			let elements = parseElements(string.dropFirst("title".count))
			guard let element = elements["title"], let title = UInt(element) else { return nil }
			guard let element = elements["entryPoint"], let entryPoint = Bool(element) else { return nil }
			guard let element = elements["index"], let index = UInt(element) else { return nil }
			self = .title(title: .init(title), entryPoint: entryPoint, index: .init(index))

		default:
			return nil
		}
	}
}

extension DVDInfo.Domain.ProgramChains.Descriptor.MenuType: CustomJSONStringKeyRepresentable, CustomJSONCodable {
	public var stringValue: String { String(describing: self) }

	public static func < (lhs: Self, rhs: Self) -> Bool {
		func sortIndex(_ value: Self) -> Int {
			switch value {
			case .titles:
				return 0
			case .rootWithinTitle:
				return 1
			case .chapter:
				return 2
			case .audio:
				return 3
			case .subpicture:
				return 4
			case .viewingAngle:
				return 5
			case .unexpected(_):
				return 6
			}
		}
		return sortIndex(lhs) < sortIndex(rhs)
	}

	/// - ToDo: Simplify using `Regex` once we move to macOS 13
	public init?(stringValue: String) {
		switch stringValue {
		case "titles": self = .titles
		case "rootWithinTitle": self = .rootWithinTitle
		case "chapter": self = .chapter
		case "audio": self = .audio
		case "subpicture": self = .subpicture
		case "viewingAngle": self = .viewingAngle
		case let string where string.hasPrefix("unexpected(") && string.hasSuffix(")"):
			let innerString = string.dropFirst("unexpected(".count).dropLast(")".count)
			guard let value = UInt8(innerString) else { return nil }
			self = .unexpected(value)
		default: return nil
		}
	}
}

extension DVDInfo.Domain.ProgramChains.Id: CustomJSONStringKeyRepresentable, CustomJSONCodable {
	public var stringValue: String {
		(languageId.map { String($0) + ":" } ?? "") + String(programChainId)
	}

	public static func < (lhs: Self, rhs: Self) -> Bool {
		switch (lhs.languageId, rhs.languageId) {
		case (.some(let lhs), .some(let rhs)) where lhs != rhs:
			return lhs < rhs
		case (.some, .some):
			return lhs.programChainId < rhs.programChainId
		case (.some, .none):
			return true
		case (.none, .some):
			return false
		case (.none, .none):
			return lhs.programChainId < rhs.programChainId
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

extension DVDInfo.ProgramChain.SubpictureDescriptor: CustomJSONStringKeyRepresentable {
	public var stringValue: String { String(describing: self) }

	public static func < (lhs: Self, rhs: Self) -> Bool {
		func sortIndex(_ value: Self) -> Int {
			switch value {
			case .classic:
				return 0
			case .wide:
				return 1
			case .letterbox:
				return 2
			case .panScan:
				return 3
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

extension DVDInfo.Interaction.ButtonDescriptor: CustomJSONStringKeyRepresentable {
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

extension DVDInfo.Command.SystemRegister: CustomJSONStringKeyRepresentable, CustomJSONCodable {
	public var stringValue: String { String(describing: self) }

	public static func < (lhs: Self, rhs: Self) -> Bool {
		func sortIndex(_ value: Self) -> Int {
			switch value {
			case .audioStreamIndex:
				return 0
			case .subpictureStreamIndex:
				return 1
			case .viewingAngleIndex:
				return 2
			case .globalTitleIndex:
				return 3
			case .titleIndex:
				return 4
			case .programChainIndex:
				return 5
			case .partIndex:
				return 6
			case .selectedButtonIndex:
				return 7
			case .navigationTimer:
				return 8
			case .programChainForTimer:
				return 9
			case .videoMode:
				return 10
			case .karaokeMode:
				return 11
			case .preferredMenuLanguage:
				return 12
			case .preferredAudioLanguage:
				return 13
			case .preferredAudioContent:
				return 14
			case .preferredSubpictureLanguage:
				return 15
			case .preferredSubpictureContent:
				return 16
			case .playerAudioCapabilities:
				return 17
			case .playerRegionMask:
				return 18
			case .parentalCountry:
				return 19
			case .parentalLevel:
				return 20
			case .reserved:
				return 21
			case .unexpected:
				return 22
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

extension DVDInfo.Index: CustomJSONStringKeyRepresentable, CustomJSONCodable {
	// custom encoding: directly use internal integer value
	public var stringValue: String { String(rawValue) }
	public init?(stringValue: String) {
		guard let uintValue = UInt(stringValue) else { return nil }
		self.init(uintValue)
	}
}

extension DVDInfo.Index: CustomStringConvertible {
	public var description: String { rawValue.description }
}

extension DVDInfo.Time: CustomJSONCodable {
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

	/// - ToDo: Simplify using `Regex` once we move to macOS 13
	public init(fromCustomJSON decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let string = try container.decode(String.self)
		var substrings = string.split(separator: ":")
		if substrings.count < 1 || substrings.count > 4 {
			throw DecodingError.dataCorruptedError(in: container,
				debugDescription: "unexpected number of time components: \(substrings.count)")
		}

		let framesAndRate = substrings.removeLast().split(separator: "@")
		if framesAndRate.count != 2 {
			throw DecodingError.dataCorruptedError(in: container,
				debugDescription: "frame count or frame rate missing")
		}
		substrings.append(contentsOf: framesAndRate)

		let components = try substrings.reversed().map {
			guard let number = UInt8($0) else {
				throw DecodingError.dataCorruptedError(in: container,
					debugDescription: "malformed time component: ‘\($0)’")
			}
			return number
		}

		let fps: Double
		switch components[0] {
		case 25: fps = 25.00
		case 30: fps = 29.97
		default: fps = Double(substrings.last!) ?? Double(components[0])
		}

		self.init(hours: components.count > 4 ? components[4] : 0,
				  minutes: components.count > 3 ? components[3] : 0,
				  seconds: components.count > 2 ? components[2] : 0,
				  frames: components[1],
				  rate: .framesPerSecond(fps))
	}
}

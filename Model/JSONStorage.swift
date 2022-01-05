import Foundation


/* MARK: JSON Data */

/// JSON representation and compressed file storage.
public struct JSON<Root: Codable> {
	public let data: Data

	init(_ root: Root) throws {
		// TODO: use custom JSON encoder
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		data = try encoder.encode(root)
	}

	func decode() throws -> Root {
		// TODO: use custom JSON decoder
		let decoder = JSONDecoder()
		return try decoder.decode(Root.self, from: data)
	}
}

extension JSON {

	/// Convert the JSON data into a string with configurable indentation.
	public func string(tabsAs format: TabFormat = .tabs) -> String {
		var result = String(data: data, encoding: .utf8)!
		if case .spaces(let width) = format {
			let lines = result.split(separator: "\n")
			let spaceIndented = lines.map { line -> String in
				let firstNonTab = line.firstIndex(where: { !$0.isWhitespace }) ?? line.startIndex
				let tabCount = line[..<firstNonTab].count
				let spaces = String(repeating: " ", count: width * tabCount)
				return spaces + line[firstNonTab...]
			}
			result = spaceIndented.joined(separator: "\n") + "\n"
		}
		return result
	}

	public enum TabFormat {
		case tabs
		case spaces(width: Int)
	}
}

// TODO: add initializer/function for reading/writing compressed files

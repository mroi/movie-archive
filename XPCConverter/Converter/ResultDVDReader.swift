/* MARK: DVDInfo */

/// Static information about the navigational and playback structure of the DVD.
public struct DVDInfo: Codable {

	public let specification: Version
	public let category: UInt32

	public let provider: String
	public let posCode: UInt64
	public let totalVolumeCount: UInt16
	public let volumeIndex: UInt16
	public let discSide: UInt8

	public init(specification: Version,
	            category: UInt32,
	            provider: String,
	            posCode: UInt64,
	            totalVolumeCount: UInt16,
	            volumeIndex: UInt16,
	            discSide: UInt8) {
		self.specification = specification
		self.category = category
		self.provider = provider
		self.posCode = posCode
		self.totalVolumeCount = totalVolumeCount
		self.volumeIndex = volumeIndex
		self.discSide = discSide
	}

	public struct Version: Codable {
		public let major: UInt8
		public let minor: UInt8

		public init(major: UInt8, minor: UInt8) {
			self.major = major
			self.minor = minor
		}
	}

	/// Index type tightly coupled to the collection element it indexes.
	///
	/// The coupling ensures that different index types cannot be confused for one another.
	public struct Index<Element>: Codable, Hashable, Strideable, ExpressibleByIntegerLiteral {
		public typealias IntegerLiteralType = UInt
		public typealias Stride = Int

		public let rawValue: UInt

		public init<T>(_ rawValue: T) where T: UnsignedInteger {
			self.rawValue = UInt(rawValue)
		}
		public init<T>(_ rawValue: T) where T: SignedInteger {
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
	public struct Reference<Root, Value>: Codable {
	}
}

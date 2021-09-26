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
}

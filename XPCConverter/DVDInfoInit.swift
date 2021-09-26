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
		          discSide: vmgiMat.disc_side)
	}
}

private extension DVDInfo.Version {
	init(_ combined: UInt8) {
		self.init(major: combined.bits(4...7), minor: combined.bits(0...3))
	}
}

import MovieArchiveConverter
import LibDVDRead


/* MARK: Toplevel */

extension DVDInfo {
	init?(_ ifoData: DVDData.IFO.All) {
		// FIXME: transfer IFO information to DVDInfo initializer
		self.init()
	}
}

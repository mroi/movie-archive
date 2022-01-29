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

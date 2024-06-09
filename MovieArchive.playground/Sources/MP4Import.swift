/* TODO: remove temporary MP4 processing once import passes generate media tree
   This file as well as the MP42Foundation and MP4v2 xcframeworks should be
   removed, once parsing manually created MP4 files is no longer my workflow. */

import Foundation
import MovieArchiveModel
import MP42Foundation


/* MARK: Media Tree from MP4  */

extension MediaTree {

	private struct DVDDataSource: MediaDataSource {}

	/// Create a single-asset media tree from an existing MP4 file.
	public init(fromMovie path: URL) throws {
		let mp4 = try MP42File(url: path)

		let videoTracks = mp4.tracks(withMediaType: kMP42MediaType_Video).compactMap {
			let track = $0 as! MP42VideoTrack
			guard track.format == kMP42VideoCodecType_H264 else { return nil as MediaRecipe.Video? }
			debugPrint(track)
			return MediaRecipe.Video(pixelAspect: Double(track.hSpacing) / Double(track.vSpacing),
			                         colorSpace: .init(primaries: track.colorPrimaries,
			                                           transfer: track.transferCharacteristics,
			                                           matrix: track.matrixCoefficients),
			                         language: .init(fromMP4Track: track.language),
			                         content: .init(characteristics: track.mediaCharacteristicTags))
		}

		let audioTracks = mp4.tracks(withMediaType: kMP42MediaType_Audio).map({
			let track = $0 as! MP42AudioTrack
			debugPrint(track)
			return MediaRecipe.Audio(channels: .init(channels: track.channels,
			                                         layout: track.channelLayoutTag),
			                         language: .init(fromMP4Track: track.language),
			                         content: .init(characteristics: track.mediaCharacteristicTags))
		}).reduce(into: []) { (result: inout [MediaRecipe.Audio], track: MediaRecipe.Audio) in
			// filter duplicate audio tracks differing only by channel layout
			let previousIndex = result.firstIndex {
				$0.language == track.language && $0.content == track.content
			}
			if let previousIndex {
				let previousTrack = result[previousIndex]
				if (track.channels?.count ?? 0) > (previousTrack.channels?.count ?? 0) {
					result.append(track)
					result.remove(at: previousIndex)
					return
				}
			}
			result.append(track)
		}

		let subtitleTracks = mp4.tracks(withMediaType: kMP42MediaType_Subtitle).map {
			let track = $0 as! MP42SubtitleTrack
			debugPrint(track)
			return MediaRecipe.Subtitles(forced: track.allSamplesAreForced,
			                             language: .init(fromMP4Track: track.language),
			                             content: .init(characteristics: track.mediaCharacteristicTags))
		}

		var recipe = MediaRecipe(data: DVDDataSource())
		recipe.stop = .seconds(Double(mp4.duration) / 1000)
		recipe.video = Dictionary(uniqueKeysWithValues: videoTracks.enumerated().map {
			(MediaRecipe.TrackIdentifier($0.offset), $0.element)
		})
		recipe.audio = Dictionary(uniqueKeysWithValues: audioTracks.enumerated().map {
			(MediaRecipe.TrackIdentifier($0.offset), $0.element)
		})
		recipe.subtitles = Dictionary(uniqueKeysWithValues: subtitleTracks.enumerated().map {
			(MediaRecipe.TrackIdentifier($0.offset), $0.element)
		})
		recipe.chapters = Dictionary(uniqueKeysWithValues: (mp4.chapters?.chapters ?? []).map {
			(.seconds(Double($0.timestamp) / 1000), $0.title)
		})
		recipe.metadata = mp4.metadata.items.compactMap({
			MediaRecipe.Metadata(identifier: $0.identifier, value: $0.value)
		}).reduce(into: []) { result, item in
			// merge partial metadata items into one
			let matches: [(MediaRecipe.Metadata) -> Bool] = [
				{ if case .title = $0 { return true } else { return false } },
				{ if case .series = $0 { return true } else { return false } },
				{ if case .episode = $0 { return true } else { return false } }
			]
			for match in matches {
				if match(item) {
					let previousIndex = result.firstIndex(where: match)
					if let previousIndex {
						result.append(item.merge(result[previousIndex]))
						result.remove(at: previousIndex)
						return
					}
				}
			}
			result.append(item)
		}

		self = .asset(.init(kind: .movie, content: recipe))
	}

	/// Create an asset collection media tree from existing MP4 files of TV series episodes.
	public init(fromEpisodes paths: [URL]) throws {
		var episodes = try paths.map { try MediaTree(fromMovie: $0) }
		episodes = episodes.map {
			// remove artist entry: MP4 files of TV episodes abuse it to store the series name
			var node = $0.asset!
			node.content.metadata.removeAll {
				if case .artist = $0 { return true } else { return false }
			}
			return .asset(node)
		}
		self = .collection(.init(children: episodes))
	}
}

fileprivate extension MediaRecipe.Video.ColorSpace {
	init(primaries: UInt16, transfer: UInt16, matrix: UInt16) {
		switch (primaries, transfer, matrix) {
		case (1, 1, 1): self = .rec709
		case (5, 1, 6): self = .rec601PAL
		case (6, 1, 6): self = .rec601NTSC
		default: fatalError("unknown color space: \(primaries), \(transfer), \(matrix)")
		}
	}
}

fileprivate extension MediaRecipe.Video.ContentInfo {
	init(characteristics: Set<String>) {
		switch characteristics {
		case let tags where tags.isEmpty: self = .main
		default: fatalError("unknown video characteristics: \(characteristics)")
		}
	}
}

fileprivate extension Array where Element == MediaRecipe.Audio.Channel {
	init?(channels: UInt32, layout: UInt32) {
		switch (channels, layout) {
		case (1, 0): self = [.frontCenter]
		case (2, 0): self = [.frontLeft, .frontRight]
		case (6, 7929862): self = [.frontLeft, .frontRight, .frontCenter, .lowFrequencyEffects, .sideLeft, .sideRight]
		default: fatalError("unknown channel layout: \(channels), \(layout)")
		}
	}
}

fileprivate extension MediaRecipe.Audio.ContentInfo {
	init(characteristics: Set<String>) {
		switch characteristics {
		case let tags where tags.isEmpty: self = .main
		default: fatalError("unknown audio characteristics: \(characteristics)")
		}
	}
}

fileprivate extension MediaRecipe.Subtitles.ContentInfo {
	init(characteristics: Set<String>) {
		switch characteristics {
		case let tags where tags.isEmpty: self = .main
		default: fatalError("unknown subtitle characteristics: \(characteristics)")
		}
	}
}

fileprivate extension MediaRecipe.Metadata {
	init?(identifier: String, value: Any?) {
		switch identifier {
		case MP42MetadataKeyName: self = .title(value as! String)
		case MP42MetadataKeyTrackSubTitle: return nil
		case MP42MetadataKeyAlbum: return nil
		case MP42MetadataKeyAlbumArtist: return nil
		case MP42MetadataKeyArtist: self = .artist(value as! String)
		case MP42MetadataKeyGrouping: self = .title("", original: (value as! String))
		case MP42MetadataKeyUserGenre: self = .genre(Genre(fromString: value as! String))
		case MP42MetadataKeyReleaseDate: self = .release(value as! Date)
		case MP42MetadataKeyTrackNumber:
			let track = value as! [Int]
			self = .episode(track[0], of: track[1], id: nil)
		case MP42MetadataKeyDiscNumber: return nil
		case MP42MetadataKeyDescription: return nil
		case MP42MetadataKeyLongDescription: self = .description(value as! String)
		case MP42MetadataKeyRating: self = .rating(Rating(fromString: value as! String))
		case MP42MetadataKeyCoverArt:
			let image = value as! MP42Image
			self = .artwork(data: image.data!, format: ImageFormat(type: image.type))
		case MP42MetadataKeyMediaKind: return nil
		case MP42MetadataKeyStudio: self = .studio(value as! String)
		case MP42MetadataKeyCast: self = .cast(value as! [String])
		case MP42MetadataKeyDirector: self = .directors(value as! [String])
		case MP42MetadataKeyProducer: self = .producers(value as! [String])
		case MP42MetadataKeyExecProducer: return nil
		case MP42MetadataKeyScreenwriters: self = .writers(value as! [String])
		case MP42MetadataKeyTVShow: self = .series(value as! String)
		case MP42MetadataKeyTVEpisodeNumber: self = .episode(value as! Int)
		case MP42MetadataKeyTVEpisodeID: self = .episode(0, of: nil, id: (value as! String))
		case MP42MetadataKeyTVSeason: self = .season(value as! Int)
		case MP42MetadataKeyContentID: return nil
		case MP42MetadataKeyGenreID: return nil
		case MP42MetadataKeyAccountCountry: return nil
		case MP42MetadataKeyPurchasedDate: return nil
		case MP42MetadataKeySortName: self = .title("", sortAs: (value as! String))
		case MP42MetadataKeySortTVShow: self = .series("", sortAs: (value as! String))
		default: fatalError("unknown metadata item: \(identifier)")
		}
	}
	func merge(_ other: Self) -> Self {
		if case var .title(title, original, sort) = self {
			if case let .title(otherTitle, otherOriginal, otherSort) = other {
				title = title.count > otherTitle.count ? title : otherTitle
				original = original ?? otherOriginal
				sort = sort ?? otherSort
				if original == title { original = nil }
				if sort == title { sort = nil }
				return .title(title, original: original, sortAs: sort)
			}
		}
		if case var .series(series, sort) = self {
			if case let .series(otherSeries, otherSort) = other {
				series = series.count > otherSeries.count ? series : otherSeries
				sort = sort ?? otherSort
				if sort == series { sort = nil }
				return .series(series, sortAs: sort)
			}
		}
		if case var .episode(index, total, id) = self {
			if case let .episode(otherIndex, otherTotal, otherId) = other {
				index = index > otherIndex ? index : otherIndex
				total = total ?? otherTotal
				id = id ?? otherId
				if id == String(index) { id = nil }
				return .episode(index, of: total, id: id)
			}
		}
		return self
	}
}

fileprivate extension MediaRecipe.Metadata.ImageFormat {
	init(type: MP42TagArtworkType) {
		switch type {
		case MP42_ART_JPEG: self = .jpeg
		case MP42_ART_PNG: self = .png
		default: fatalError("unknown image type: \(type)")
		}
	}
}

fileprivate extension MediaRecipe.Metadata.Genre {
	init(fromString genre: String) {
		switch genre {
		case "Action": self = .action
		case "Animation": self = .animation
		case "Drama": self = .drama
		case "Horror": self = .horror
		case "Kinder und Familie": self = .kidsAndFamily
		case "Komödien": self = .comedy
		case "Kurzfilme": self = .shorts
		case "Liebesfilme": self = .romance
		case "Musicals": self = .musical
		case "Science-Fiction und Fantasy": self = .scienceFictionAndFantasy
		case "Thriller": self = .thriller
		case "Western": self = .western
		default: fatalError("unknown genre: \(genre)")
		}
	}
}

fileprivate extension MediaRecipe.Metadata.Rating {
	init(fromString rating: String) {
		let ratingCode = rating.split(separator: "|")[2]
		switch ratingCode {
		case "100": self = .age(6)
		case "200": self = .age(12)
		case "500": self = .age(16)
		case "600": self = .age(18)
		default: fatalError("unknown rating: \(rating)")
		}
	}
}

fileprivate extension Locale {
	init?(fromMP4Track language: String) {
		switch language {
		case "und": return nil
		case let lang where Locale.availableIdentifiers.contains(lang):
			self = Locale(identifier: language)
		default: fatalError("unknown language: \(language)")
		}
	}
}

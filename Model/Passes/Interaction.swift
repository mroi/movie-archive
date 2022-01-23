extension Base {

	/// A pass allowing the client to interact with the media tree.
	public struct MediaTreeInteraction: Pass {
		public init() {}
		public func process(_ mediaTree: MediaTree) async -> MediaTree {
			var mediaTree = mediaTree
			await Transform.clientInteraction(&mediaTree, Transform.Status.mediaTree)
			return mediaTree
		}
	}
}

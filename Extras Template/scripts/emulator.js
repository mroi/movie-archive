if (!window.iTunes) {
	window.iTunes = {
		platform: 'Emulator',
		
		findTracksByXID: function (xid) {
			return Array();
		},
		
		play: function (file, metadata) {
			player.video.src = file;
			player.video.controls = true;
			player.highlight.style.display = 'none';
			player.navigation.style.display = 'none';
			player.video.play();
			// FIXME: how do we get out of here
		},
		
		getSystemSounds: function () {
			return null;
		}
	};
}

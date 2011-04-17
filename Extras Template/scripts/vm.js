var vm = {
	version: 1,
	current: null,
	menu: 0,
	buttonSet: 0,
	button: 0,
	
	playMenu: function (id) {
		// FIXME: add support for pre- and post-commands (they do exist in menus, right?)
		vm.menu = id;
		// FIXME: activation time for next button set
		vm.buttonSet = 0;
		// FIXME: default button
		vm.button = 0;
		
		vm.current = player.pickLanguage(content.menu[vm.menu]);
		player.updateMenu();
		window.iTunes.allowDisplaySleep();
	},
	
	playFeature: function (id) {
		vm.playFeatureFromChapter(id, null);
	},
	
	playFeatureFromChapter: function (id, chapter) {
		// FIXME: add support for pre- and post-commands
		var found = false;
		
		player.video.pause();
		
		if (!found && typeof content.feature[id].xid === 'string') {
			var tracks = window.iTunes.findTracksByXID(content.feature[id].xid);
			if (tracks.length > 0) {
				if (chapter !== null)
					tracks[0].play({ startChapterIndex: chapter });
				else
					tracks[0].play();
				found = true;
			}	else
				window.console.log("XID '" + content.feature[id].xid + "' not found in iTunes library");
		}
		
		if (!found && typeof content.feature[id].file === 'string') {
			var metadata = new Object();
			if (chapter !== null)
				metadata['startChapterIndex'] = chapter;
			if (typeof content.feature[id].title === 'object')
				metadata['title'] = player.pickLanguage(content.feature[id].title);
			else
				metadata['title'] = player.lookupMetadata('itemName');
			metadata['artist'] = player.lookupMetadata('artistName');
			metadata['album'] = player.lookupMetadata('playlistName');
			window.iTunes.play('videos/' + content.feature[id].file, metadata);
			// FIXME: can we find out, whether it went wrong? (same above)
			found = true;
		}
		
		if (!found)
			window.console.log("feature " + id + " could not be played");
		else
			window.iTunes.preventDisplaySleep();
			// FIXME: allowDisplaySleep when playback returns
		
		// FIXME: setup window event handlers for videoclosed and fullyended (at least they sound like what we want, other interesting events: timeupdate - execute things during playback?, playingtrackchanged - for playlists with multiple tracks?, unload - unknown?, play, pause)
		
		// searching the iTunes binary for strings around 'startChapterIndex' reveals some interesting things: stopChapterIndex, startTimeOffset, stopTimeOffset; may be interesting for 
		// other interesting stuff: setVisibleHUDParts, currentChapter, currentPlayingTrack
	},
	
	navigate: function (navigation) {
		var handled = false;
		
		if (navigation === 'back') {
			var back = vm.current.back;
			if (typeof back === 'function') {
				back();
				handled = true;
			}
		} else {
			var button = vm.current.set[vm.buttonSet].button[vm.button];
			if (typeof button[navigation] === 'number') {
				vm.button = button[navigation];
				player.updateHighlight();
				if (button.autoAction)
					vm.action()
				handled = true;
			}
		}
		
		return handled;
	},
	
	action: function () {
		player.updateHighlight();
		var action = vm.current.set[vm.buttonSet].button[vm.button].action;
		if (typeof action === 'function')
			action();
	}
};

var vm = {
	version: 1,
	menu: 0,
	buttonSet: 0,
	button: 0,
	
	playMenu: function (id) {
		vm.menu = id;
		// FIXME: activation time for next button set
		vm.buttonSet = 0;
		// FIXME: default button
		vm.button = 0;
		
		player.updateMenu();
	},
	
	playFeature: function (id) {
		player.video.pause();
		// FIXME: how do we properly return from this function? what comes next?
		
		if (typeof content.feature[id].xid == 'string') {
			var tracks = window.iTunes.findTracksByXID(content.feature[id].xid);
			if (tracks.length > 0) {
				tracks[0].play();
				return;
			}	else
				window.console.log("XID '" + content.feature[id].xid + "' not found in iTunes library");
		}
		
		if (typeof content.feature[id].file == 'string') {
			var metadata = new Object();
			if (typeof content.feature[id].title == 'object')
				metadata['title'] = content.feature[id].title[player.language];
			metadata['artist'] = player.lookupMetadata('artistName');
			metadata['album'] = player.lookupMetadata('playlistName');
			window.iTunes.play('videos/' + content.feature[id].file, metadata);
			return;
		}
		
		window.console.log("feature " + id + " could not be played");
	},
	
	navigate: function (navigation) {
		var handled = false;
		
		if (navigation == 'back') {
			var back = content.menu[vm.menu][player.language].back;
			if (typeof back == 'function') {
				back();
				handled = true;
			}
		} else {
			var button = content.menu[vm.menu][player.language].set[vm.buttonSet].button[vm.button];
			if (typeof button[navigation] == 'number') {
				vm.button = button[navigation];
				player.updateHighlight();
				if (button.autoAction)
					window.setTimeout("vm.action()", 0);
				handled = true;
			}
		}
		
		return handled;
	},
	
	action: function () {
		var old_menu = vm.menu;
		content.menu[vm.menu][player.language].set[vm.buttonSet].button[vm.button].action();
		player.activated = false;
		if (vm.menu == old_menu)
			player.updateHighlight();
	}
};

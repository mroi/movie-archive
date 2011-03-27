var vm = {
	menu: 0,
	buttonSet: 0,
	button: 0,
	// FIXME: language hardcoded
	language: 'de',
	
	playMenu: function (id) {
		vm.menu = id;
		// FIXME: activation time for next button set
		vm.buttonSet = 0;
		// FIXME: default button
		vm.button = 0;
		
		player.updateMenu('highlight');
	},
	
	playFeature: function (id) {
		if (content.feature[id].xid) {
			var tracks = window.iTunes.findTracksByXID(content.feature[id].xid);
			if (tracks.length > 0)
				tracks[0].play();
			else
				window.console.log("XID '" + content.feature[id].xid + "' not found in iTunes library.");
		} else {
			// FIXME pass title, artist and album in object argument
			window.iTunes.play('videos/' + content.feature[id].file, {});
		}
	},
	
	navigate: function (navigation) {
		var button = content.menu[vm.menu][vm.language].set[vm.buttonSet].button[vm.button];
		vm.button = button[navigation];
		player.update('highlight');
		if (button.autoAction)
			vm.action();
	},
	
	action: function () {
		var old_menu = vm.menu;
		content.menu[vm.menu][vm.language].set[vm.buttonSet].button[vm.button].action();
		if (vm.menu == old_menu)
			player.update('highlight');
	}
};

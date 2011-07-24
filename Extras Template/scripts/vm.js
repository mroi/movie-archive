"use strict";

var vm = {
	version: 1,
	
	register: new Array(),
	// TODO: emulate SPRM registers as DVDs need them, use getter and setter
	
	links: null,
	triggers: null,
	lastSeenTimeUpdate: null,
	schedulePost: false,
	jumpcount: 0,
	lastMenu: 0,
	
	overlay: null,
	buttonSet: null,
	button: 0,
	
	playMenu: function (id, options) {
		if (typeof content.menu[id] !== 'object') return;
		vm.jumpcount++;
		
		if (typeof content.menu[id].links === 'object')
			vm.links = content.menu[id].links;
		else
			vm.links = null;
		if (typeof content.menu[id].triggers === 'object')
			vm.triggers = content.menu[id].triggers;
		else
			vm.triggers = null;
		vm.lastSeenTimeUpdate = null;
		vm.schedulePost = false;
		
		if (vm.links && typeof vm.links.pre === 'function') {
			var jumpcount = vm.jumpcount;
			vm.links.pre();
			if (vm.jumpcount > jumpcount)
				return;  // playback jumped somewhere else
		}
		// FIXME: add support for menu post-commands
		// FIXME: menus with still/hold-timeout need to setup a timer
		
		vm.lastMenu = id;
		vm.overlay = player.pickLanguage(content.menu[id]);
		vm.buttonSet = null;
		
		if (typeof options === 'object' && typeof options.select === 'number')
			vm.button = options.select;
		
		player.updateMenu();
	},
	
	playFeature: function (id, options) {
		if (typeof content.feature[id] !== 'object') return;
		vm.jumpcount++;
		
		if (typeof content.feature[id].links === 'object')
			vm.links = content.feature[id].links;
		else
			vm.links = null;
		if (typeof content.feature[id].triggers === 'object')
			vm.triggers = content.feature[id].triggers;
		else
			vm.triggers = null;
		vm.lastSeenTimeUpdate = null;
		vm.schedulePost = false;
		
		if (vm.links && typeof vm.links.pre === 'function') {
			var jumpcount = vm.jumpcount;
			vm.links.pre();
			if (vm.jumpcount > jumpcount)
				return;  // playback jumped somewhere else
		}
		
		var found = false;
		
		if (typeof content.feature[id].overlay === 'object') {
			// overlays cannot be displayed on top of the iTunes player, so we stay in menu mode and use an HTML5 player
			if (window.iTunes.platform === 'AppleTV') {
				player.showAlert(_('This feature is not supported on Apple TV.'), 12);
			} else {
				vm.overlay = content.feature[id].overlay;
				vm.buttonSet = null;
				// TODO: HTML5 player for VTS-PGCs with overlays
			}
			
		} else {
			vm.overlay = null;
			vm.buttonSet = null;
			
			// FIXME: use temporary playlist, if we expect multiple consecutive PGCs (using PGC->next)
			if (!found && typeof content.feature[id].xid === 'string') {
				var tracks = window.iTunes.findTracksByXID(content.feature[id].xid);
				if (tracks.length > 0) {
					if (typeof options === 'object' && typeof options.chapter === 'number')
						tracks[0].play({ startChapterIndex: options.chapter });
					else
						tracks[0].play();
					found = true;
				}	else
					window.console.log("XID '" + content.feature[id].xid + "' not found in iTunes library");
			}
			
			if (!found && typeof content.feature[id].file === 'string') {
				var metadata = new Object();
				if (typeof options === 'object' && typeof options.chapter === 'number')
					metadata['startChapterIndex'] = options.chapter;
				if (typeof content.feature[id].title === 'object')
					metadata['title'] = player.pickLanguage(content.feature[id].title);
				else
					metadata['title'] = player.lookupMetadata('itemName');
				metadata['artist'] = player.lookupMetadata('artistName');
				metadata['album'] = player.lookupMetadata('playlistName');
				window.iTunes.play('videos/' + content.feature[id].file, metadata);
				found = true;
			}
		}
		
		if (found) {
			var jumpcount = vm.jumpcount;
			window.setTimeout(function () {
				if (jumpcount === vm.jumpcount && window.iTunes.currentPlayerState === window.iTunes.StoppedState && !vm.schedulePost) {
					// playback has not started yet, something's wrong with this video
					window.console.log("an error occurred while playing feature " + id);
					vm.playback({ type: 'videoclosed' });
				}
			}, 5000);
		} else {
			window.console.log("feature " + id + " could not be found");
			vm.playback({ type: 'videoclosed' });
		}
	},
	
	activateButtons: function (id) {
		if (vm.overlay && typeof vm.overlay.set[id] === 'object') {
			vm.buttonSet = id;
			player.prefetchHighlights();
			if (typeof vm.overlay.set[vm.buttonSet].select === 'number')
				vm.button = vm.overlay.set[vm.buttonSet].select;
			if (vm.button >= vm.overlay.set[vm.buttonSet].button.length)
				vm.button = vm.overlay.set[vm.buttonSet].button.length - 1;
		} else
			vm.buttonSet = null;
		player.updateMouseHotspots();
		player.updateHighlight();
	},
	
	navigate: function (navigation) {
		var handled = false;
		
		if (navigation === 'back') {
			if (vm.links && typeof vm.links.back === 'function') {
				var jumpcount = vm.jumpcount;
				vm.links.back();
				if (vm.jumpcount > jumpcount)
					handled = true;
			}
		} else if (vm.overlay && typeof vm.overlay.set[vm.buttonSet] === 'object') {
			var button = vm.overlay.set[vm.buttonSet].button[vm.button];
			if (typeof button[navigation] === 'number') {
				vm.button = button[navigation];
				if (vm.button >= vm.overlay.set[vm.buttonSet].button.length)
					vm.button = vm.overlay.set[vm.buttonSet].button.length - 1;
				player.updateHighlight();
				if (button.autoAction)
					vm.action()
				handled = true;
			}
		}
		
		return handled;
	},
	
	action: function () {
		var jumpcount = vm.jumpcount;
		if (vm.overlay && typeof vm.overlay.set[vm.buttonSet] === 'object') {
			var action = vm.overlay.set[vm.buttonSet].button[vm.button].action;
			if (typeof action === 'function')
				action();
		}
		if (jumpcount === vm.jumpcount)
			player.updateHighlight();
	},
	
	playback: function (event) {
		switch (event.type) {
			// FIXME: playingtrackchanged event - for playlists with multiple tracks?
			case 'play':
				player.menu.style.display = 'none';
				// TODO: don't pause if we are using the HTML5 player
				player.video.pause();
				// TODO: pause menu audio for stills
				if (typeof window.iTunes.preventDisplaySleep === 'function')
					window.iTunes.preventDisplaySleep();
				break;
				
			case 'timeupdate':
				// we assume this gets called at least once per second, the W3C spec defines a minimum of 4Hz for HTML5 video
				// AppleTV does not use this event and also stops all JavaScript timers during playback, so we cannot emulate it
				if (window.iTunes.currentPlayingTrack && window.iTunes.currentPlayerState !== window.iTunes.StoppedState) {
					var current = window.iTunes.currentTime;
					var duration = window.iTunes.currentPlayingTrack.duration;
					var regularPlayback = window.iTunes.currentPlayerState === window.iTunes.PlayingState;
					// TODO: get these from elsewhere if this is an HTML5 video
				} else
					return;
				
				if (regularPlayback) {
					/* check if we need to change the current overlay */
					if (vm.overlay && typeof vm.overlay.set === 'object') {
						for (var i = 0; i < vm.overlay.set.length; i++) {
							if (typeof vm.overlay.set[i].start === 'number')
								var start = vm.overlay.set[i].start;
							else
								var start = 0;
							if (typeof vm.overlay.set[i].stop === 'number')
								var stop = vm.overlay.set[i].stop;
							else
								var stop = Number.POSITIVE_INFINITY;
							if (current >= start && current < stop) {
								if (vm.buttonSet !== i)	vm.activateButtons(i);
								break;
							}
						}
						if (i === vm.overlay.set.length && vm.buttonSet !== null)
							vm.activateButtons(null);
					}
					
					/* check if we need to execute playback triggers */
					if (vm.triggers && current - vm.lastSeenTimeUpdate < 1) {
						for (var i = 0; i < vm.triggers.length; i++) {
							if (current >= vm.triggers[i].time && vm.lastSeenTimeUpdate < vm.triggers[i].time)
								vm.triggers[i].action();  // FIXME: crazy jumps might happen
						}
					}
				} else {
					if (vm.buttonSet !== null)
						vm.activateButtons(null);
				}
				
				if (duration - current < 1)
					vm.schedulePost = true;
				else
					vm.schedulePost = false;
				
				vm.lastSeenTimeUpdate = current;
				break;
				
			case 'videoclosed':
				var jumpcount = vm.jumpcount;
				if (vm.schedulePost && vm.links && typeof vm.links.post === 'function')
					vm.links.post();
				if (jumpcount === vm.jumpcount)
					vm.navigate('back');
				if (jumpcount === vm.jumpcount)
					vm.playMenu(vm.lastMenu);
				if (typeof window.iTunes.allowDisplaySleep === 'function')
					window.iTunes.allowDisplaySleep();
				window.iTunes.stop();
				break;
		}
	}
};

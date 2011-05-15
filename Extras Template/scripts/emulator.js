if (!window.iTunes) {
	window.iTunes = {
		StoppedState: 0,
		PlayingState: 1,
		FastForwardingState: 2,  // unused playback state
		RewindingState: 3,       // unused playback state
		
		acceptedLanguages: 'en',
		platform: 'Emulator',
		currentPlayerState: 0,
		currentPlayingTrack: null,
		currentTime: 0,
		
		findTracksByXID: function (xid) {
			return new Array();
		},
		
		play: function (file, metadata) {
			player.emulator.controls = true;
			player.emulator.src = file;
			
			window.iTunes.savedTitle = document.title;
			if (typeof metadata.title === 'string' && metadata.title.length) {
				var albumName = player.lookupMetadata('playlistName');
				if (albumName && albumName != metadata.title)
					document.title = albumName + ' — ' + metadata.title;
				else
					document.title = metadata.title;
			}
			
			player.emulator.play();
			window.iTunes.currentPlayerState = window.iTunes.PlayingState;
			window.iTunes.currentPlayingTrack = new Object();
			window.iTunes.currentTime = 0;
		},
		
		stop: function () {
			window.iTunes.currentPlayingTrack = null;
			window.iTunes.currentTime = 0;
			window.iTunes.injectEvent('timeupdate');
			document.title = window.iTunes.savedTitle;
		},
		
		getSystemSounds: function () {
			return null;
		},
		
		allowDisplaySleep: function () {},
		preventDisplaySleep: function () {},
		
		/* private section, not part of the iTunes interface */
		
		savedTitle: '',
		
		close: function () {
			player.emulator.pause();
			window.iTunes.currentPlayerState = window.iTunes.StoppedState;
			player.emulator.style.display = 'none';
			player.sizeChanged();
		},
		
		injectEvent: function(type) {
			var event = document.createEvent('HTMLEvents');
			event.initEvent(type, false, false);
			window.dispatchEvent(event);
		}
	};
}

function emulator_init()
{
	window.iTunes.acceptedLanguages = navigator.language;
	
	window.addEventListener('keydown', function (event) {
		if (window.iTunes.currentPlayerState === window.iTunes.PlayingState && (event.keyCode == KEYBOARD_ESCAPE || event.keyCode == KEYBOARD_BACKSPACE)) {
			window.iTunes.close();
			window.iTunes.injectEvent('videoclosed');
		}
	}, false);
	player.emulator.addEventListener('loadedmetadata', function (event) {
		player.emulator.style.display = 'block';
		window.iTunes.injectEvent('play');
		player.sizeChanged();
	}, false);
	player.emulator.addEventListener('durationchange', function (event) {
		window.iTunes.currentPlayingTrack.duration = player.emulator.duration;
	}, false);
	player.emulator.addEventListener('timeupdate', function (event) {
		window.iTunes.currentTime = player.emulator.currentTime;
		window.iTunes.injectEvent('timeupdate');
	}, false);
	player.emulator.addEventListener('ended', function (event) {
		window.iTunes.close();
		window.iTunes.injectEvent('videoclosed');
	}, false);
	player.emulator.addEventListener('error', window.iTunes.close, false);
}

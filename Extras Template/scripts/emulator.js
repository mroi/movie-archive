if (!window.iTunes) {
	window.iTunes = {
		acceptedLanguages: 'en',
		platform: 'Emulator',
		
		findTracksByXID: function (xid) {
			return Array();
		},
		
		play: function (file, metadata) {
			player.menu.style.display = 'none';
			player.emulator.style.display = 'block';
			player.emulator.controls = true;
			player.emulator.src = file;
			player.sizeChanged();
			
			window.iTunes.saved.title = document.title;
			if (typeof metadata.title === 'string' && metadata.title.length) {
				var albumName = player.lookupMetadata('playlistName');
				if (albumName && albumName != metadata.title)
					document.title = albumName + ' — ' + metadata.title;
				else
					document.title = metadata.title;
			}
			
			window.iTunes.saved.keyDownHandler = window.onkeydown;
			window.onkeydown = function (event) {
				if (event.keyCode == KEYBOARD_ESCAPE || event.keyCode == KEYBOARD_BACKSPACE) {
					window.iTunes.restore();
					event.stopPropagation();
					event.preventDefault();
				}
			};
			
			player.emulator.play();
		},
		
		getSystemSounds: function () {
			return null;
		},
		
		allowDisplaySleep: function () {},
		preventDisplaySleep: function () {},
		
		/* private section, not part of the iTunes interface */
		
		saved: {
			title: '',
			keyDownHandler: null
		},
		
		restore: function () {
			player.emulator.pause();
			player.emulator.style.display = 'none';
			player.menu.style.display = 'block';
			player.sizeChanged();
			document.title = window.iTunes.saved.title;
			window.onkeydown = window.iTunes.saved.keyDownHandler;
		}
	};
}

function emulator_init()
{
	window.iTunes.acceptedLanguages = navigator.language;
	
	player.emulator.style.display = 'none';
	player.emulator.addEventListener('ended', function (event) {
		window.iTunes.restore();
	}, false);
}

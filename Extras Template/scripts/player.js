const KEYBOARD_BACKSPACE = 8;
const KEYBOARD_RETURN = 13;
const KEYBOARD_ESCAPE = 27;
const KEYBOARD_LEFT = 37;
const KEYBOARD_UP = 38;
const KEYBOARD_RIGHT = 39;
const KEYBOARD_DOWN = 40;

var player;

function player_init()
{
	/* helper function to compare relative and absolute URIs */
	String.prototype.endsWith = function (end) {
		return end === this.substr(this.length - end.length, end.length);
	};
	
	player = {
		version: 1,
		view: document.getElementById('view'),
		menu: document.getElementById('menu'),
		still: document.getElementById('still'),
		video: document.getElementById('video'),
		highlight: document.getElementById('highlight'),
		navigation: document.getElementById('navigation'),
		emulator: document.getElementById('emulator'),
		alert: document.getElementById('alert'),
		
		metadata: null,
		activated: false,
		
		pickLanguage: function (object) {
			var langList = window.iTunes.acceptedLanguages;
			if (object.fallback)
				var bestMatch = object.fallback;
			else
				var bestMatch = null;
			for (var lang in object) {
				if ((langList.indexOf(lang) >= 0 && langList.indexOf(bestMatch) == -1) || (langList.indexOf(lang) >= 0 && langList.indexOf(lang) < langList.indexOf(bestMatch)))
					bestMatch = lang;
			}
			if (!bestMatch) {
				for (var lang in object) {
					bestMatch = lang;  // pick any language
					break;
				}
			}
			return bestMatch ? object[bestMatch] : null;
		},
		
		sizeChanged: function () {
			if (!window.innerHeight) return;
			
			var windowAspect = window.innerWidth / window.innerHeight;
			
			if (player.emulator.style.display === 'block')
				playerAspect = player.emulator.videoWidth / player.emulator.videoHeight;
			else if (player.video.style.display === 'block')
				playerAspect = player.video.videoWidth / player.video.videoHeight;
			else if (player.still.style.display === 'block')
				playerAspect = player.still.naturalWidth / player.still.naturalHeight;
			else
				playerAspect = 16 / 9;
			
			if (playerAspect < windowAspect) {
				player.view.style.width = Math.round(window.innerHeight * playerAspect) + 'px';
				player.view.style.height = window.innerHeight + 'px';
				player.view.style.marginTop = '0';
				player.view.style.marginLeft = Math.round((window.innerWidth - window.innerHeight * playerAspect) / 2) + 'px';
			} else {
				player.view.style.width = window.innerWidth + 'px';
				player.view.style.height = Math.round(window.innerWidth / playerAspect) + 'px';
				player.view.style.marginTop = Math.round((window.innerHeight - window.innerWidth / playerAspect) / 2) + 'px';
				player.view.style.marginLeft = '0';
			}
			player.alert.style.fontSize = Math.round(player.view.offsetHeight / 20) + 'px';
			
			player.updateMouseHotspots();
		},
		
		lookupMetadata: function (item) {
			item = item.replace(/\u200b/g, '');  // why on earth is there a zero-width space at the end of string literals?
			if (player.metadata) {
				for (var node = player.metadata.firstChild; node; node = node.nextSibling) {
					if (node.nodeName === 'key' && node.firstChild.data === item) {
						do {
							node = node.nextSibling;
						} while (node.nodeType === 3);
						return node.firstChild.data;
					}
				}
			}
			return null;
		},
		
		prefetchHighlights: function () {
			if (vm.overlay && typeof vm.overlay.set[vm.buttonSet] === 'object') {
				var base = 'images/' + vm.overlay.prefix;
				if (vm.overlay.set.length > 1)
					base += '_set' + (vm.buttonSet < 10 ? '0' : '') + vm.buttonSet;
				
				for (var btn = 0; btn < vm.overlay.set[vm.buttonSet].button.length; btn++) {
					var btnBase = base + '_btn' + (btn < 10 ? '0' : '') + btn;
					(new Image()).src = btnBase + '_highlight.png';
					(new Image()).src = btnBase + '_activated.png';
				}
			}
		},
		
		updateMenu: function () {
			if (!vm.overlay) return;
			
			/* setup menu video */
			if (window.iTunes.platform !== 'AppleTV') {
				var video = 'menus/' + vm.overlay.prefix + '.m4v';
				player.highlight.style.display = 'none';
				if (player.video.src.endsWith(video)) {
					if (!player.video.error) {
						player.video.currentTime = 0;
						player.video.play();
						player.menu.style.display = 'block';
					}
				} else {
					player.video.src = video;
					player.video.play();
				}
			}
			
			/* setup still backdrop */
			if (window.iTunes.platform === 'AppleTV' || player.video.error) {
				var jumpcount = vm.jumpcount;
				
				/* execute triggers preceding button set 0 */
				if (vm.triggers && vm.overlay && typeof vm.overlay.set === 'object') {
					if (typeof vm.overlay.set[0].start === 'number')
						var start = vm.overlay.set[0].start;
					else
						var start = 0;
					for (var i = 0; i < vm.triggers.length && jumpcount === vm.jumpcount; i++) {
						if (vm.triggers[i].time <= start)
							vm.triggers[i].action();
						else
							break;
					}
				}
				
				if (jumpcount === vm.jumpcount) {
					// TODO: play menu audio
					var still = 'images/' + vm.overlay.prefix + '.jpg';
					player.highlight.style.display = 'none';
					if (player.still.src.endsWith(still)) {
						player.menu.style.display = 'block';
						vm.activateButtons(0);
					} else {
						player.still.src = still;
					}
				}
			}
		},
		
		updateMouseHotspots: function () {
			while (player.navigation.firstChild)
				player.navigation.removeChild(player.navigation.firstChild);
			if (vm.overlay && typeof vm.overlay.set[vm.buttonSet] === 'object') {
				// When hotspot areas overlap, the DVD spec says the higher button number takes precedence. In HTML5, events are deliverd to the top-most area, with the first area element in tree-order being the top-most. Thus, we create area tags in reverse button-order.
				for (var btn = vm.overlay.set[vm.buttonSet].button.length - 1; btn >= 0; btn--) {
					var button = vm.overlay.set[vm.buttonSet].button[btn];
					if (typeof button.x1 === 'number' &&
							typeof button.y1 === 'number' &&
							typeof button.x2 === 'number' &&
							typeof button.y2 === 'number') {
						var x1 = Math.round(button.x1 * player.view.offsetWidth);
						var y1 = Math.round(button.y1 * player.view.offsetHeight);
						var x2 = Math.round(button.x2 * player.view.offsetWidth);
						var y2 = Math.round(button.y2 * player.view.offsetHeight);
						var area = document.createElement('area');
						area.alt = 'button' + btn;
						area.shape = 'rect';
						area.coords = x1 + ',' + y1 + ',' + x2 + ',' + y2;
						area.tabindex = btn + 1;
						area.style.cursor = 'pointer';
						area.href = '#';
						area.button = btn;
						area.onmouseover = function () {
							vm.button = this.button;
							player.updateHighlight();
						};
						area.onmousedown = function() {
							vm.button = this.button;
							var event = document.createEvent("HTMLEvents");
							event.initEvent('keydown', false, true);
							event.keyCode = KEYBOARD_RETURN;
							window.dispatchEvent(event);
						};
						player.navigation.appendChild(area);
					}
				}
			}
		},
		
		updateHighlight: function () {
			if (vm.overlay && typeof vm.overlay.set[vm.buttonSet] === 'object') {
				var base = 'images/' + vm.overlay.prefix;
				if (vm.overlay.set.length > 1)
					base += '_set' + (vm.buttonSet < 10 ? '0' : '') + vm.buttonSet;
				var buttonState = player.activated ? 'activated' : 'highlight';
				var button = base + '_btn' + (vm.button < 10 ? '0' : '') + vm.button + '_' + buttonState + '.png';
				
				if (player.highlight.src.endsWith(button))
					player.highlight.style.display = 'block';
				else
					player.highlight.src = button;
			} else
				player.highlight.src = 'images/none.png';
			
			player.activated = false;
		},
		
		keyPressed: function (event) {
			if (!player.activated && window.iTunes.currentPlayerState === window.iTunes.StoppedState) {
				var handled = false;
				
				switch (event.keyCode) {
					case KEYBOARD_LEFT:
						handled = vm.navigate('left');
						break;
					case KEYBOARD_UP:
						handled = vm.navigate('up');
						break;
					case KEYBOARD_RIGHT:
						handled = vm.navigate('right');
						break;
					case KEYBOARD_DOWN:
						handled = vm.navigate('down');
						break;
					case KEYBOARD_RETURN:
						player.activated = true;
						player.updateHighlight();
						window.setTimeout(vm.action, 250);
						handled = true;
						break;
					case KEYBOARD_ESCAPE:
					case KEYBOARD_BACKSPACE:
						handled = vm.navigate('back');
						break;
				}
				
				switch (event.keyCode) {
					case KEYBOARD_LEFT:
					case KEYBOARD_UP:
					case KEYBOARD_RIGHT:
					case KEYBOARD_DOWN:
						if (handled)
							player.navigationSound('ScrollStart');
						else
							player.navigationSound('ScrollLimit');
						break;
					case KEYBOARD_ESCAPE:
					case KEYBOARD_BACKSPACE:
						player.navigationSound('Exit');
						break;
					case KEYBOARD_RETURN:
						player.navigationSound('Select');
						break;
				}
				
				if (handled) {
					event.stopPropagation();
					event.preventDefault();
				}
			}
		},
		
		navigationSound: function (sound) {
			if (window.iTunes.platform === 'AppleTV') {
				var sounds = window.iTunes.getSystemSounds();
				var soundName = 'SystemSound' + sound;
				if (sounds && sounds[soundName])
					sounds.playSystemSound(sounds[soundName]);
			}
		},
		
		showAlert: function (text, time) {
			player.alert.innerHTML = text;
			player.alert.style.opacity = '1';
			window.setTimeout(function () {
				player.alert.style.opacity = '0'
			}, time * 1000);
		}
	};
	
	/* check version numbers and initialize components */
	if (content.version != player.version ||
	    player.version != vm.version ||
	    vm.version != content.version)
		player.showAlert(_('Inconsistent Versions'), 10);
	if (window.iTunes.platform === 'Emulator')
		emulator_init();
	player.emulator.style.display = 'none';
	
	/* set up event handling */
	window.addEventListener('keydown', player.keyPressed, true);
	window.addEventListener('resize', player.sizeChanged, false);
	window.addEventListener('play', vm.playback, false);
	window.addEventListener('timeupdate', vm.playback, false);
	window.addEventListener('videoclosed', vm.playback, false);
	player.still.onload = function (event) {
		player.menu.style.display = 'block';
		player.still.style.display = 'block';
		player.sizeChanged();
		vm.activateButtons(0);
	};
	player.still.onerror = function (event) {
		player.still.style.display = 'none';
		vm.activateButtons(0);
	};
	player.highlight.onload = function (event) {
		player.menu.style.display = 'block';
		player.highlight.style.display = 'block';
	};
	player.highlight.onerror = function (event) {
		player.highlight.src = 'images/none.png';
	};
	if (window.iTunes.platform !== 'AppleTV') {
		player.video.addEventListener('loadedmetadata', function (event) {
			player.menu.style.display = 'block';
			player.video.style.display = 'block';
			player.sizeChanged();
		}, false);
		player.video.addEventListener('error', function (event) {
			player.video.style.display = 'none';
			player.updateMenu();
		}, false);
	}
	
	/* fetch Extras metadata file */
	var request = new XMLHttpRequest();
	request.open('GET', 'iTunesMetadata.plist', false);
	request.send();
	if (request.readyState === 4 && (request.status === 0 || request.status === 200)) {
		function skipTextNodes(node) {
			while (node.nodeType === 3)
				node = node.nextSibling;
			return node;
		}
		var plist = request.responseXML.getElementsByTagName('plist')[0];
		var dict = skipTextNodes(plist.firstChild);
		if (dict.nodeName === 'dict') {
			for (var node = dict.firstChild; node; node = node.nextSibling) {
				if (node.nodeName === 'key' && node.firstChild.data === 'Metadata') {
					var metadata = skipTextNodes(node.nextSibling);
					if (metadata.nodeName === 'dict')
						player.metadata = metadata;
					break;
				}
			}
		}
	} else
		window.console.log("could not load iTunesMetadata.plist");
	
	var title = player.lookupMetadata('itemName');
	if (title)
		document.title = title;
	else
		document.title = _(document.title);  // at least localize
	
	if (typeof window.iTunes.allowDisplaySleep === 'function')
		window.iTunes.allowDisplaySleep();
	
	/* rock'n'roll */
	if (typeof content.start === 'function')
		content.start();
	else
		vm.playMenu(0);
}

window.onload = player_init;

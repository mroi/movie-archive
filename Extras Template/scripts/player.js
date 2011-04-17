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
			
			/* update view size and margins */
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
			
			/* update mouse hotspots */
			while (player.navigation.firstChild)
				player.navigation.removeChild(player.navigation.firstChild);
			// FIXME: compare the precedence of area-tags with what the DVD says when button areas overlap
			for (var btn = 0; btn < vm.current.set[vm.buttonSet].button.length; btn++) {
				var button = vm.current.set[vm.buttonSet].button[btn];
				if (typeof button.x1 === 'number' &&
				    typeof button.y1 === 'number' &&
				    typeof button.x2 === 'number' &&
				    typeof button.y2 === 'number') {
					var x1 = Math.round((button.x1 / player.still.naturalWidth) * player.view.offsetWidth);
					var y1 = Math.round((button.y1 / player.still.naturalHeight) * player.view.offsetHeight);
					var x2 = Math.round((button.x2 / player.still.naturalWidth) * player.view.offsetWidth);
					var y2 = Math.round((button.y2 / player.still.naturalHeight) * player.view.offsetHeight);
					var area = document.createElement('area');
					area.alt = 'button' + btn;
					area.shape = 'rect';
					area.coords = x1 + ',' + y1 + ',' + x2 + ',' + y2;
					area.tabindex = btn;
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
		
		updateMenu: function () {
			/* setup menu video */
			player.video.style.display = 'none';
			
			/* setup still backdrop */
			// FIXME: update still only when on Apple TV or in a still-only menu
			var base = 'images/' + vm.current.prefix;
			if (vm.current.set.length > 1)
				base += '_set' + (vm.buttonSet < 10 ? '0' : '') + vm.buttonSet;
			var still = base + '.jpg';
			if (still != player.still.src) {
				player.highlight.style.display = 'none';
				var img = new Image();
				img.onload = function () {
					player.still.style.display = 'block';
					player.still.src = this.src;
					player.sizeChanged();
					player.updateHighlight();
				};
				img.onerror = function () {
					player.still.style.display = 'none';
					player.updateHighlight();
				};
				img.src = still;
			}
			
			/* tigger prefetch for highlight images */
			for (var btn = 0; btn < vm.current.set[vm.buttonSet].button.length; btn++) {
				var btnBase = base + '_btn' + (btn < 10 ? '0' : '') + btn;
				(new Image()).src = btnBase + '_highlight.png';
				(new Image()).src = btnBase + '_activated.png';
			}
		},
		
		updateHighlight: function () {
			var base = 'images/' + vm.current.prefix;
			if (vm.current.set.length > 1)
				base += '_set' + (vm.buttonSet < 10 ? '0' : '') + vm.buttonSet;
			var buttonState = player.activated ? 'activated' : 'highlight';
			var button = base + '_btn' + (vm.button < 10 ? '0' : '') + vm.button + '_' + buttonState + '.png';
			
			if (button != player.highlight.src) {
				player.highlight.style.display = 'block';
				player.highlight.src = button;
			}
			
			player.activated = false;
		},
		
		keyPressed: function (event) {
			if (!player.activated) {
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
	
	/* check version numbers of all components */
	if (content.version != player.version ||
	    player.version != vm.version ||
	    vm.version != content.version)
		player.showAlert(_('Inconsistent Versions'), 8);
	
	/* setup event handling */
	window.onkeydown = player.keyPressed;
	window.onresize = player.sizeChanged;
	player.still.onload = player.sizeChanged;
	player.video.onload = player.sizeChanged;
	player.emulator.onload = player.sizeChanged;
	
	/* fetch Extras metadata file */
	var request = new XMLHttpRequest();
	request.open('GET', 'iTunesMetadata.plist', false);
	request.send();
	if (request.readyState === 4 && request.status === 0) {
		function skipTextNodes(node)
		{
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
	
	if (window.iTunes.platform === 'Emulator')
		emulator_init();
	
	/* rock'n'roll */
	content.start();
}

window.onload = player_init;

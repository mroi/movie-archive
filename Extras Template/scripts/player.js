const KEYBOARD_BACKSPACE = 8;
const KEYBOARD_RETURN = 13;
const KEYBOARD_ESCAPE = 27;
const KEYBOARD_LEFT = 37;
const KEYBOARD_UP = 38;
const KEYBOARD_RIGHT = 39;
const KEYBOARD_DOWN = 40;

var player;

function init()
{
	player = {
		version: 1,
		menu: document.getElementById('menu'),
		still: document.getElementById('still'),
		video: document.getElementById('video'),
		highlight: document.getElementById('highlight'),
		navigation: document.getElementById('navigation'),
		alert: document.getElementById('alert'),
		
		metadata: null,
		// FIXME: language hardcoded
		language: 'de',
		activated: false,
		
		sizeChanged: function () {
			if (!window.innerHeight) return;
			
			var windowAspect = window.innerWidth / window.innerHeight;
			
			if (player.video.src.length > 0)
				playerAspect = player.video.videoWidth / player.video.videoHeight;
			else
				playerAspect = player.still.naturalWidth / player.still.naturalHeight;
			
			if (playerAspect < windowAspect) {
				player.menu.style.width = Math.round(window.innerHeight * playerAspect) + 'px';
				player.menu.style.height = window.innerHeight + 'px';
				player.menu.style.marginTop = '0';
				player.menu.style.marginLeft = Math.round((window.innerWidth - window.innerHeight * playerAspect) / 2) + 'px';
			} else {
				player.menu.style.width = window.innerWidth + 'px';
				player.menu.style.height = Math.round(window.innerWidth / playerAspect) + 'px';
				player.menu.style.marginTop = Math.round((window.innerHeight - window.innerWidth / playerAspect) / 2) + 'px';
				player.menu.style.marginLeft = '0';
			}
		},
		
		lookupMetadata: function (item) {
			item = item.replace(/\u200b/g, '');  // why on earth is there a zero-width space at the end of string literals?
			if (player.metadata) {
				for (var node = player.metadata.firstChild; node; node = node.nextSibling) {
					if (node.nodeName == 'key' && node.firstChild.data == item) {
						do {
							node = node.nextSibling;
						} while (node.nodeType == 3);
						return node.firstChild.data;
					}
				}
			}
			return null;
		},
		
		updateMenu: function () {
			var base = 'images/menu' + (vm.menu < 10 ? '0' : '') + vm.menu + '_' + player.language;
			var still = base + '.jpg';
			if (still != player.still.src)
				player.still.src = still;
			player.activated = false;
			
			/* tigger prefetch for all highlight images */
			for (var set = 0; set < content.menu[vm.menu][player.language].set.length; set++) {
				for (var btn = 0; btn < content.menu[vm.menu][player.language].set[set].button.length; btn++) {
					var urlBase = base + '_set' + (set < 10 ? '0' : '') + set + '_btn' + (btn < 10 ? '0' : '') + btn;
					(new Image()).src = urlBase + '_highlight.png';
					(new Image()).src = urlBase + '_activated.png';
				}
			}
			
			player.updateHighlight();
		},
		
		updateHighlight: function () {
			var base = 'images/menu' + (vm.menu < 10 ? '0' : '') + vm.menu + '_' + player.language;
			var buttonSet = base + '_set' + (vm.buttonSet < 10 ? '0' : '') + vm.buttonSet;
			var buttonState = player.activated ? 'activated' : 'highlight';
			var button = buttonSet + '_btn' + (vm.button < 10 ? '0' : '') + vm.button + '_' + buttonState + '.png';
			if (button != player.highlight.src)
				player.highlight.src = button;
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
						window.setTimeout("vm.action()", 250);
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
			if (window.iTunes.platform == 'AppleTV') {
				var sounds = window.iTunes.getSystemSounds();
				var soundName = 'SystemSound' + sound;
				if (sounds && sounds[soundName])
					sounds.playSystemSound(sounds[soundName]);
			}
		},
		
		showAlert: function (text, time) {
			player.alert.innerHTML = text;
			player.alert.style.opacity = '1';
			window.setTimeout("player.alert.style.opacity = '0'", time);
		}
	};
	
	if (content.version != player.version ||
	    player.version != vm.version ||
	    vm.version != content.version)
		player.showAlert(_('Inconsistent Versions'), 6000);
	
	window.onkeydown = player.keyPressed;
	window.onresize = player.sizeChanged;
	player.still.onload = player.sizeChanged;
	player.video.onload = player.sizeChanged;
	
	var request = new XMLHttpRequest();
	request.open('GET', 'iTunesMetadata.plist', false);
	request.send();
	if (request.readyState == 4 && request.status == 0) {
		function skipText(node)
		{
			while (node.nodeType == 3)
				node = node.nextSibling;
			return node;
		}
		var plist = request.responseXML.getElementsByTagName('plist')[0];
		var dict = skipText(plist.firstChild);
		if (dict.nodeName == 'dict') {
			for (var node = dict.firstChild; node; node = node.nextSibling) {
				if (node.nodeName == 'key' && node.firstChild.data == 'Metadata') {
					var metadata = skipText(node.nextSibling);
					if (metadata.nodeName == 'dict')
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
	
	content.start();
}

window.onload = init;

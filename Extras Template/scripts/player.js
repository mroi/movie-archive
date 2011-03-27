const KEYBOARD_BACKSPACE = 8;
const KEYBOARD_RETURN = 13;
const KEYBOARD_LEFT = 37;
const KEYBOARD_UP = 38;
const KEYBOARD_RIGHT = 39;
const KEYBOARD_DOWN = 40;

var player;

function init()
{
	player = {
		menu: document.getElementById('menu'),
		still: document.getElementById('still'),
		video: document.getElementById('video'),
		highlight: document.getElementById('highlight'),
		navigation: document.getElementById('navigation'),
		
		sizeChanged: function () {
			if (!window.innerHeight) return;
			
			var windowAspect = window.innerWidth / window.innerHeight;
			var playerAspect;
			
			if (player.video.src.length > 0)
				playerAspect = player.video.width / player.video.height;
			else
				playerAspect = player.still.naturalWidth / player.still.naturalHeight;
			
			if (playerAspect < windowAspect) {
				player.menu.style.width = window.innerHeight * playerAspect + 'px';
				player.menu.style.height = window.innerHeight + 'px';
				player.menu.style.marginTop = '0';
				player.menu.style.marginLeft = (window.innerWidth - window.innerHeight * playerAspect) / 2 + 'px';
			} else {
				player.menu.style.width = window.innerWidth + 'px';
				player.menu.style.height = window.innerWidth / playerAspect + 'px';
				player.menu.style.marginTop = (window.innerHeight - window.innerWidth / playerAspect) / 2 + 'px';
				player.menu.style.marginLeft = '0';
			}
		},
		
		update: function (state) {
			var base = 'images/menu' + (vm.menu < 10 ? '0' : '') + vm.menu + '_' + vm.language;
			
			var still = base + '.jpg';
			if (still != player.still.src)
				player.still.src = still;
			
			var buttonSet = base + '_set' + (vm.buttonSet < 10 ? '0' : '') + vm.buttonSet;
			var button = buttonSet + '_btn' + (vm.button < 10 ? '0' : '') + vm.button + '_' + state + '.png';
			if (button != player.highlight.src)
				player.highlight.src = button;
		},
		
		keyPressed: function (event) {
			switch (event.keyCode) {
				case KEYBOARD_LEFT:
					vm.navigate('left');
					return true;
				case KEYBOARD_UP:
					vm.navigate('up');
					return true;
				case KEYBOARD_RIGHT:
					vm.navigate('right');
					return true;
				case KEYBOARD_DOWN:
					vm.navigate('down');
					return true;
				case KEYBOARD_RETURN:
					player.update('activate');
					window.setTimeout("vm.action()", 250);
					return true;
				// TODO: is this enough or do we want to handle backspace?
			}
		}
	};
	
	window.onkeydown = player.keyPressed;
	window.onresize = player.sizeChanged;
	player.still.onload = player.sizeChanged;
	
	content.start();
}

window.onload = init;

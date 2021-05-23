// @ts-check

// @ts-expect-error
if (error) throw Error("browser incompatible");


class Player {

	constructor() {
		document.body.style.display = "grid";
		document.body.style.height = "100%";
		document.body.style.margin = "0";

		// container div
		const container = document.createElement("div");
		container.style.position = "relative";
		container.style.margin = "auto";
		document.body.append(container);

		// main video player
		const video = document.createElement("video");
		video.controls = true;
		video.style.display = "block";
		video.style.outline = "none";
		video.addEventListener("resize", event => {
			let aspect = this.video.videoWidth / this.video.videoHeight;
			if (!aspect)
				aspect = this.video.scrollWidth / this.video.scrollHeight;
			if (aspect) {
				this.video.style.width = "min(100vw, " + aspect * 100 + "vh)";
				this.video.style.height = "min(100vh, " + 1/aspect * 100 + "vw)";
			}
		});
		container.append(video);
		this.video = video;

		// menu container
		let menu = document.createElement("div");
		menu.style.width = "100%";
		menu.style.height = "100%";
		menu.style.position = "absolute";
		menu.style.top = "0";
		menu.style.fontSize = "4vmin";
		container.append(menu);
		this.menu = menu;
	}

	/** @param {string[]} urls */
	async loadVideo(...urls) {
		/** @type {string | undefined} */
		let hlsUrl;

		this.video.innerHTML = "";
		urls.forEach(url => {
			const extension = url.split(".").pop();
			const source = document.createElement("source");
			switch (extension) {
			case "m4v":
			case "mp4":
				source.type = "video/mp4";
				break;
			case "m3u8":
				source.type = "application/vnd.apple.mpegurl";
				hlsUrl = hlsUrl ?? url;
				break;
			case "webm":
				source.type = "video/webm";
				break;
			default:
				return;
			}
			source.src = url;
			this.video.append(source);
		});

		// check for native HLS support or load JavaScript implementation
		if (hlsUrl && this.video.canPlayType("application/vnd.apple.mpegURL") != "maybe") {
			// load HTTP live streaming support, when native browser support is unavailable:
			// https://github.com/video-dev/hls.js
			if (typeof Hls == "undefined")
				await this.loadScript("hls.js");
			if (Hls.isSupported()) {
				const hls = new Hls();
				hls.on(Hls.Events.MEDIA_ATTACHED, () => {
					hls.loadSource(hlsUrl);
				});
				hls.attachMedia(this.video);
			}
		}
	}

	/** @param {string} url */
	async loadScript(url) {
		// add a script tag instead of dynamic imports to circumvent same-origin restrictions
		return new Promise((resolve, reject) => {
			const script = document.createElement("script");
			script.src = url;
			script.addEventListener("load", event => {
				resolve(true);
			});
			script.addEventListener("error", event => {
				reject();
			});
			document.body.append(script);
		});
	}
}


document.addEventListener("DOMContentLoaded", event => {
	const player = new Player();
	// TODO: hard-coded setup
	document.title = "Im toten Winkel";
	player.menu.style.pointerEvents = "none";
	player.loadVideo("movie.m3u8", "movie.mp4", "movie.webm");
	player.video.poster = "/files/justiceinc/preview.jpg";
});

with import <nixpkgs> {};
let bin = [
	autoconf automake libtool pkg-config meson ninja cmake nasm
];
in derivation {
	name = "shell";
	builder = "/usr/bin/false";
	system = builtins.currentSystem;
	PATH = builtins.foldl' (x: y: "${x}${y}/bin:") "" bin + (builtins.getEnv "PATH");
	ACLOCAL_PATH = "${libtool}/share/aclocal";
}

{
	description = "build environment for dependencies";
	inputs.nixpkgs.url = "flake:nixpkgs/nixpkgs-unstable";
	outputs = { self, nixpkgs }: let
		systems = [ "aarch64-darwin" "x86_64-darwin" ];
		lib = import "${nixpkgs}/lib";
		forAll = list: f: lib.genAttrs list f;
	in {
		devShells = forAll systems (system: {
			default = with import nixpkgs { inherit system; };
				mkShellNoCC {
					packages = [
						autoconf automake libtool pkg-config meson ninja cmake nasm
					];
					shellHook = ''
						export ACLOCAL_PATH="${libtool}/share/aclocal:${pkg-config}/share/aclocal";
					'';
				};
		});
	};
}

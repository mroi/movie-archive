{
	description = "build environment for dependencies";
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
						export ACLOCAL_PATH="${libtool}/share/aclocal:${pkg-config}/share/aclocal"
						export NIX_CC="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr"
					'';
				};
		});
	};
}

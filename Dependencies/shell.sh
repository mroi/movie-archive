#!/bin/sh
# use the Nix package manager if available
if test -x ~/.nix-profile/bin/nix-shell ; then
	for arg do
		args="$args '$arg'"
	done
	eval HOME=~
	export NIX_PATH="${NIX_PATH:-nixpkgs=$HOME/.nix-defexpr/channels/nixpkgs}"
	exec ~/.nix-profile/bin/nix-shell --run "exec /bin/sh $args"
else
	exec /bin/sh "$@"
fi

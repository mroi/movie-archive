ifneq ($(shell which nix-build),)
TSC ?= $(shell nix-build --no-out-link -A nodePackages.typescript '<nixpkgs>')/bin/tsc
endif
TSC ?= tsc

.PHONY: check force

check: $(wildcard *.js)

%.js: force
	$(TSC) --noEmit --allowJs --strict --lib ES6,DOM $@

force:

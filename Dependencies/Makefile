ARCHS ?= x86_64
CONFIGURATION ?= Debug
JOBS = -j$(shell sysctl -n hw.activecpu)
BUILD = Build/$(CONFIGURATION)

XDG_STATE_HOME ?= $(HOME)/.local/state
NIX ?= $(XDG_STATE_HOME)/nix/profile/bin/nix

ifneq ($(wildcard $(NIX)),)
# use Nix package manager
SHELL = $(NIX) develop --command /bin/sh
endif

all: \
	$(BUILD)/HandBrake/libhandbrake.a \
	$(foreach arch,$(ARCHS),$(BUILD)/HandBrake/$(arch)/module.modulemap) \
	$(BUILD)/MP42Foundation/libmp42.a \
	$(if $(wildcard libdvdcss),$(BUILD)/libdvdcss/libdvdcss.2.dylib)

.PHONY: all install clean docbuild


# MARK: HandBrake

.INTERMEDIATE: $(foreach arch,$(ARCHS),$(BUILD)/HandBrake/$(arch)/libhb/libhandbrake.a $(BUILD)/HandBrake/$(arch)/GNUmakefile)

$(BUILD)/HandBrake/libhandbrake.a: $(foreach arch,$(ARCHS),$(BUILD)/HandBrake/$(arch)/libhb/libhandbrake.a)
	lipo $^ -create -output $@
	for lib in $(addsuffix /../contrib/lib/lib*.a,$(<D)) ; do \
		lib=`basename $$lib` ; lipo $(addsuffix /../contrib/lib/$$lib,$(^D)) -create -output $(@D)/$$lib ; \
	done
	find $(@D) -depth -mindepth 1 ! -path "$(@D)/lib*.a" $(foreach arch,$(ARCHS),! -path "$(@D)/$(arch)/contrib/include/*" ! -path "$(@D)/$(arch)/libhb/handbrake/*") -delete || true
	rm -rf HandBrake/download

$(BUILD)/HandBrake/%/libhb/libhandbrake.a: $(BUILD)/HandBrake/%/GNUmakefile
	# FIXME: needed as an undeclared dependency of libhb.build
	$(MAKE) -C $(<D) bin2c.build
	# FIXME: parallel HandBrake builds fail
	$(MAKE) -C $(<D) libhb.build

$(BUILD)/HandBrake/%/GNUmakefile: HandBrake/configure
	rm -rf $(@D) ; mkdir -p $(@D) ; cd $(@D) ; \
	optimize=$(shell case $(CONFIGURATION) in (Debug) echo none ;; (Release) echo speed ;; esac) ; \
	debug=$(shell case $(CONFIGURATION) in (Debug) echo std ;; (Release) echo none ;; esac) ; \
	$(abspath $<) --arch=$* --optimize=$$optimize --debug=$$debug --disable-xcode

HandBrake/configure: ../.git/modules/Dependencies/HandBrake/HEAD

$(BUILD)/HandBrake/%/module.modulemap: HandBrake.modulemap
	ln -sf ../../../../$< $@


# MARK: MP42Foundation

$(BUILD)/MP42Foundation/libmp42.a: ../.git/modules/Dependencies/MP42Foundation/HEAD
	patch -p1 -dMP42Foundation < MP42Foundation.patch
	rm -rf $(@D) ; mkdir -p $(@D) ; cd MP42Foundation ; \
	xcodebuild build -configuration $(CONFIGURATION) -target mp42 ARCHS="$(ARCHS)" \
		CONFIGURATION_BUILD_DIR="../$(@D)"
	patch -p1 -dMP42Foundation -R < MP42Foundation.patch
	rm -rf MP42Foundation/build


# MARK: libdvdcss

.INTERMEDIATE: $(foreach arch,$(ARCHS),$(BUILD)/libdvdcss/$(arch)/.libs/libdvdcss.2.dylib $(BUILD)/libdvdcss/$(arch)/Makefile)
.PRECIOUS: libdvdcss/configure

$(BUILD)/libdvdcss/libdvdcss.2.dylib: $(foreach arch,$(ARCHS),$(BUILD)/libdvdcss/$(arch)/.libs/libdvdcss.2.dylib)
	lipo $^ -create -output $@
	$(foreach arch,$(ARCHS),$(MAKE) -C $(BUILD)/libdvdcss/$(arch) maintainer-clean ;)
	find $(@D) -type d -empty -delete

$(BUILD)/libdvdcss/%/.libs/libdvdcss.2.dylib: $(BUILD)/libdvdcss/%/Makefile
	$(MAKE) $(JOBS) -C $(<D)

$(BUILD)/libdvdcss/%/Makefile: libdvdcss/configure
	rm -rf $(@D) ; mkdir -p $(@D) ; cd $(@D) ; \
	arch=$(shell case $* in (i386) echo -m32 ;; (x86_64) echo -m64 ;; (arm64) echo -arch\\ arm64 ;; esac) ; \
	optimize=$(shell case $(CONFIGURATION) in (Debug) echo -O0 ;; (Release) echo -O3 ;; esac) ; \
	debug=$(shell case $(CONFIGURATION) in (Debug) echo -g ;; esac) ; \
	$(abspath $<) --host=$*-apple-darwin10 CFLAGS="$$arch $$optimize $$debug"

libdvdcss/configure: ../.git/modules/Dependencies/libdvdcss/HEAD
	cd $(@D) ; autoreconf -i


../.git/modules/Dependencies/%/HEAD:
	git submodule update --init --depth 1 --single-branch --recursive $*

install:
	unset BUILD_ROOT ; $(MAKE) all

clean:
	rm -rf Build

docbuild:

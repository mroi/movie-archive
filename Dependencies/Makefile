SHELL = ./shell.sh
ARCHS ?= x86_64
CONFIGURATION ?= Debug
BUILD = Build/$(CONFIGURATION)

all: $(BUILD)/HandBrake/libhandbrake.a $(if $(wildcard libdvdcss),$(BUILD)/libdvdcss/libdvdcss.2.dylib)

.PHONY: all clean


.INTERMEDIATE: $(foreach arch,$(ARCHS),$(BUILD)/HandBrake/$(arch)/libhb/libhandbrake.a $(BUILD)/HandBrake/$(arch)/GNUmakefile)

$(BUILD)/HandBrake/libhandbrake.a: $(foreach arch,$(ARCHS),$(BUILD)/HandBrake/$(arch)/libhb/libhandbrake.a)
	lipo $^ -create -output $@
	for lib in $(addsuffix /../contrib/lib/*.a,$(<D)) ; do \
		lib=`basename $$lib` ; lipo $(addsuffix /../contrib/lib/$$lib,$(^D)) -create -output $(@D)/$$lib ; \
	done
	$(foreach arch,$(ARCHS),$(MAKE) -C $(BUILD)/HandBrake/$(arch) contrib.clean libhb.clean ;)
	rm -rf HandBrake/download

$(BUILD)/HandBrake/%/libhb/libhandbrake.a: $(BUILD)/HandBrake/%/GNUmakefile
	$(MAKE) -C $(<D) libhb.build

$(BUILD)/HandBrake/%/GNUmakefile: HandBrake/configure ../.git/modules/Dependencies/HandBrake/HEAD
	rm -rf $(@D) ; mkdir -p $(@D) ; cd $(@D) ; \
	optimize=$(shell case $(CONFIGURATION) in (Debug) echo none ;; (Release) echo speed ;; esac) ; \
	debug=$(shell case $(CONFIGURATION) in (Debug) echo std ;; (Release) echo none ;; esac) ; \
	$(abspath $<) --arch=$* --optimize=$$optimize --debug=$$debug --disable-xcode


.INTERMEDIATE: $(foreach arch,$(ARCHS),$(BUILD)/libdvdcss/$(arch)/src/.libs/libdvdcss.2.dylib $(BUILD)/libdvdcss/$(arch)/Makefile libdvdcss/configure)

$(BUILD)/libdvdcss/libdvdcss.2.dylib: $(foreach arch,$(ARCHS),$(BUILD)/libdvdcss/$(arch)/src/.libs/libdvdcss.2.dylib)
	lipo $^ -create -output $@
	$(foreach arch,$(ARCHS),$(MAKE) -C $(BUILD)/libdvdcss/$(arch) maintainer-clean ;)

$(BUILD)/libdvdcss/%/src/.libs/libdvdcss.2.dylib: $(BUILD)/libdvdcss/%/Makefile
	$(MAKE) -C $(<D)

$(BUILD)/libdvdcss/%/Makefile: libdvdcss/configure
	rm -rf $(@D) ; mkdir -p $(@D) ; cd $(@D) ; \
	arch=$(shell case $* in (i386) echo -m32 ;; (x86_64) echo -m64 ;; esac) ; \
	optimize=$(shell case $(CONFIGURATION) in (Debug) echo -O0 ;; (Release) echo -O3 ;; esac) ; \
	debug=$(shell case $(CONFIGURATION) in (Debug) echo -g ;; esac) ; \
	$(abspath $<) --host=$*-apple-darwin10 CFLAGS="$$arch $$optimize $$debug"

libdvdcss/configure: ../.git/modules/Dependencies/libdvdcss/HEAD
	cd $(@D) ; ./bootstrap


clean:
	rm -rf Build

SHELL = ./shell.sh
ARCHS ?= x86_64
CONFIGURATION ?= Debug
JOBS = -j$(shell sysctl -n hw.activecpu)
BUILD = Build/$(CONFIGURATION)

all: \
	$(BUILD)/HandBrake/libhandbrake.a \
	$(foreach arch,$(ARCHS),$(BUILD)/HandBrake/$(arch)/module.modulemap) \
	$(if $(wildcard libdvdcss),$(BUILD)/libdvdcss/libdvdcss.2.dylib)

.PHONY: all install clean


.INTERMEDIATE: $(foreach arch,$(ARCHS),$(BUILD)/HandBrake/$(arch)/libhb/libhandbrake.a $(BUILD)/HandBrake/$(arch)/GNUmakefile)

$(BUILD)/HandBrake/libhandbrake.a: $(foreach arch,$(ARCHS),$(BUILD)/HandBrake/$(arch)/libhb/libhandbrake.a)
	lipo $^ -create -output $@
	for lib in $(addsuffix /../contrib/lib/lib*.a,$(<D)) ; do \
		lib=`basename $$lib` ; lipo $(addsuffix /../contrib/lib/$$lib,$(^D)) -create -output $(@D)/$$lib ; \
	done
	find $(@D) -mindepth 1 ! -path "$(@D)/lib*.a" $(foreach arch,$(ARCHS),! -path "$(@D)/$(arch)/contrib/include/*" ! -path "$(@D)/$(arch)/libhb/handbrake/*") -delete
	rm -rf HandBrake/download

$(BUILD)/HandBrake/%/libhb/libhandbrake.a: $(BUILD)/HandBrake/%/GNUmakefile
	$(MAKE) $(JOBS) -C $(<D) libhb.build

$(BUILD)/HandBrake/%/GNUmakefile: HandBrake/configure ../.git/modules/Dependencies/HandBrake/HEAD
	rm -rf $(@D) ; mkdir -p $(@D) ; cd $(@D) ; \
	optimize=$(shell case $(CONFIGURATION) in (Debug) echo none ;; (Release) echo speed ;; esac) ; \
	debug=$(shell case $(CONFIGURATION) in (Debug) echo std ;; (Release) echo none ;; esac) ; \
	$(abspath $<) --arch=$* --optimize=$$optimize --debug=$$debug --disable-xcode


$(BUILD)/HandBrake/%/module.modulemap: HandBrake.modulemap
	ln -sf ../../../../$< $@


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
	arch=$(shell case $* in (i386) echo -m32 ;; (x86_64) echo -m64 ;; esac) ; \
	optimize=$(shell case $(CONFIGURATION) in (Debug) echo -O0 ;; (Release) echo -O3 ;; esac) ; \
	debug=$(shell case $(CONFIGURATION) in (Debug) echo -g ;; esac) ; \
	$(abspath $<) --host=$*-apple-darwin10 CFLAGS="$$arch $$optimize $$debug"

libdvdcss/configure: ../.git/modules/Dependencies/libdvdcss/HEAD
	cd $(@D) ; autoreconf -i


install:
	unset BUILD_ROOT ; $(MAKE) all

clean:
	rm -rf Build

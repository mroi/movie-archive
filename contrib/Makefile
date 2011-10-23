all: handbrake $(if $(wildcard $(PROJECT_DIR)/contrib/libdvdcss),libdvdcss) $(BUILT_PRODUCTS_DIR)
	@cd "$(BUILT_PRODUCTS_DIR)" ; ln -sf "$(TARGET_TEMP_DIR)" "External Libraries"

.PHONY: handbrake libdvdcss clean

CONTRIB_VERSION = $(wildcard $(PROJECT_DIR)/contrib/.svn/dir-props $(PROJECT_DIR)/contrib/.svn/dir-prop-base)


handbrake: $(TARGET_TEMP_DIR)/handbrake/libhb.a

HANDBRAKE_EXTRA_LIBS = libdvdread

.INTERMEDIATE: $(foreach arch, $(ARCHS), $(TARGET_TEMP_DIR)/handbrake/$(arch)/libhb/libhb.a $(TARGET_TEMP_DIR)/handbrake/$(arch)/GNUmakefile)

$(TARGET_TEMP_DIR)/handbrake/libhb.a: $(foreach arch, $(ARCHS), $(TARGET_TEMP_DIR)/handbrake/$(arch)/libhb/libhb.a)
	lipo $^ -create -output $@
	$(foreach lib, $(HANDBRAKE_EXTRA_LIBS), lipo $(addsuffix /../contrib/lib/$(lib).a,$(^D)) -create -output $(@D)/$(lib).a ;)
	$(foreach arch, $(ARCHS), $(MAKE) -C $(TARGET_TEMP_DIR)/handbrake/$(arch) contrib.clean libhb.clean ;)
	rm -rf $(PROJECT_DIR)/contrib/handbrake/download

$(TARGET_TEMP_DIR)/handbrake/%/libhb/libhb.a: $(TARGET_TEMP_DIR)/handbrake/%/GNUmakefile
	$(MAKE) -C $(<D) libhb.build

$(TARGET_TEMP_DIR)/handbrake/%/GNUmakefile: $(CONTRIB_VERSION)
	rm -rf $(@D) ; mkdir -p $(@D) ; cd $(@D) ; \
	optimize=$(shell case $(CONFIGURATION) in (Debug) echo none ;; (Release) echo speed ;; esac) ; \
	debug=$(shell case $(CONFIGURATION) in (Debug) echo std ;; (Release) echo none ;; esac) ; \
	$(PROJECT_DIR)/contrib/handbrake/configure \
		--arch=$* --optimize=$$optimize --debug=$$debug \
		--disable-xcode --disable-gtk \
		LIBOGG.GCC.args.extra=-O3 LIBVORBIS.GCC.args.extra=-O3  # FIXME: LTO fails with llvm-gcc-4.2


libdvdcss: $(TARGET_TEMP_DIR)/libdvdcss/libdvdcss.2.dylib

.INTERMEDIATE: $(foreach arch, $(ARCHS), $(TARGET_TEMP_DIR)/libdvdcss/$(arch)/src/.libs/libdvdcss.2.dylib $(TARGET_TEMP_DIR)/libdvdcss/$(arch)/Makefile $(PROJECT_DIR)/contrib/libdvdcss/configure)

$(TARGET_TEMP_DIR)/libdvdcss/libdvdcss.2.dylib: $(foreach arch, $(ARCHS), $(TARGET_TEMP_DIR)/libdvdcss/$(arch)/src/.libs/libdvdcss.2.dylib)
	lipo $^ -create -output $@
	$(foreach arch, $(ARCHS), $(MAKE) -C $(TARGET_TEMP_DIR)/libdvdcss/$(arch) maintainer-clean ;)

$(TARGET_TEMP_DIR)/libdvdcss/%/src/.libs/libdvdcss.2.dylib: $(TARGET_TEMP_DIR)/libdvdcss/%/Makefile
	$(MAKE) -C $(<D)

$(TARGET_TEMP_DIR)/libdvdcss/%/Makefile: $(PROJECT_DIR)/contrib/libdvdcss/configure
	rm -rf $(@D) ; mkdir -p $(@D) ; cd $(@D) ; \
	arch=$(shell case $* in (i386) echo -m32 ;; (x86_64) echo -m64 ;; esac) ; \
	optimize=$(shell case $(CONFIGURATION) in (Debug) echo -O0 ;; (Release) echo -O3 ;; esac) ; \
	debug=$(shell case $(CONFIGURATION) in (Debug) echo -g ;; esac) ; \
	$(PROJECT_DIR)/contrib/libdvdcss/configure \
		--host=$*-apple-darwin10 CFLAGS="$$arch $$optimize $$debug"

$(PROJECT_DIR)/contrib/libdvdcss/configure: $(CONTRIB_VERSION)
	cd $(@D) ; ./bootstrap


$(BUILT_PRODUCTS_DIR):
	mkdir -p $@

clean:
	rm -rf "$(TARGET_TEMP_DIR)"
	rm -f "$(BUILT_PRODUCTS_DIR)/External Libraries"

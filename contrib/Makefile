all: handbrake
	@cd "$(BUILT_PRODUCTS_DIR)" ; ln -sf "$(TARGET_TEMP_DIR)" "External Libraries"

.PHONY: handbrake clean


handbrake: $(TARGET_TEMP_DIR)/handbrake/libhb.a 

.INTERMEDIATE: $(foreach arch, $(ARCHS), $(TARGET_TEMP_DIR)/handbrake/$(arch)/libhb/libhb.a)

$(TARGET_TEMP_DIR)/handbrake/libhb.a: $(foreach arch, $(ARCHS), $(TARGET_TEMP_DIR)/handbrake/$(arch)/libhb/libhb.a)
	lipo $^ -create -output $@
	$(foreach arch, $(ARCHS), $(MAKE) -C $(TARGET_TEMP_DIR)/handbrake/$(arch) contrib.clean libhb.clean)

$(TARGET_TEMP_DIR)/handbrake/%/libhb/libhb.a: $(TARGET_TEMP_DIR)/handbrake/%/GNUmakefile
	$(MAKE) -C $(<D) libhb.build

$(TARGET_TEMP_DIR)/handbrake/%/GNUmakefile:
	mkdir -p $(@D) ; cd $(@D) ; \
	optimize=$(shell case $(CONFIGURATION) in (Debug) echo none ;; (Release) echo speed ;; esac) ; \
	debug=$(shell case $(CONFIGURATION) in (Debug) echo std ;; (Release) echo none ;; esac) ; \
	$(PROJECT_DIR)/contrib/handbrake/configure \
		--arch=$* --optimize=$$optimize --debug=$$debug \
		--disable-xcode --disable-gtk


clean:
	rm -rf "$(TARGET_TEMP_DIR)"
	rm -f "$(BUILT_PRODUCTS_DIR)/External Libraries"

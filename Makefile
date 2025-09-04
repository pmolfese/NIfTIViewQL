# Variables
NIFTI_CLIB_REPO=https://github.com/NIFTI-Imaging/nifti_clib.git
NIFTI_CLIB_DIR=nifti_clib
PROJECT_NAME=NIfTIViewQL
XCODE_PROJECT=$(PROJECT_NAME).xcodeproj
XCODE_SCHEME=NIfTIViewQuickLook
XCODE_CONFIGURATION=Release
DERIVED_DATA=./output

LIB_DEST_DIR=NIfTIViewQL/nifti_clib
BRIDGING_HEADER=$(LIB_DEST_DIR)/NiftiQuickView-Bridging-Header.h

ZLIB_REPO=https://github.com/madler/zlib.git
ZLIB_DIR=zlib
ZLIB_LIB=$(ZLIB_DIR)/libz.a

.PHONY: all zlib nifti_clib bridging-header xcodebuild app install clean

all: zlib nifti_clib bridging-header xcodebuild app

zlib:
	@if [ ! -d "$(ZLIB_DIR)" ]; then \
		echo "Cloning zlib..."; \
		git clone $(ZLIB_REPO) $(ZLIB_DIR); \
	fi
	@cd $(ZLIB_DIR) && make clean || true
	@cd $(ZLIB_DIR) && ./configure
	@cd $(ZLIB_DIR) && make
	@mkdir -p $(LIB_DEST_DIR)
	@if [ -f "$(ZLIB_LIB)" ]; then \
		cp $(ZLIB_LIB) $(LIB_DEST_DIR)/; \
	fi
	@if [ -d "$(ZLIB_DIR)/include" ]; then \
		cp -R $(ZLIB_DIR)/include/* $(LIB_DEST_DIR)/; \
	fi

nifti_clib: zlib
	@if [ ! -d "$(NIFTI_CLIB_DIR)" ]; then \
		echo "Cloning nifti_clib..."; \
		git clone $(NIFTI_CLIB_REPO) $(NIFTI_CLIB_DIR); \
	fi
	@cd $(NIFTI_CLIB_DIR) && make clean
	@cd $(NIFTI_CLIB_DIR) && make all
	@mkdir -p $(LIB_DEST_DIR)
	@if [ -d "$(NIFTI_CLIB_DIR)/lib" ]; then \
		cp -R $(NIFTI_CLIB_DIR)/lib/* $(LIB_DEST_DIR)/; \
	fi
	@if [ -d "$(NIFTI_CLIB_DIR)/include" ]; then \
		cp -R $(NIFTI_CLIB_DIR)/include/* $(LIB_DEST_DIR)/; \
	fi
	@if [ -f "$(NIFTI_CLIB_DIR)/libniftiio.a" ]; then \
		cp $(NIFTI_CLIB_DIR)/libniftiio.a $(LIB_DEST_DIR)/; \
	fi

bridging-header:
	@mkdir -p $(LIB_DEST_DIR)
	@echo '#include "nifti1_io.h"' > $(BRIDGING_HEADER)
	@echo '#include "nifti1.h"' >> $(BRIDGING_HEADER)
	@echo '#include "znzlib.h"' >> $(BRIDGING_HEADER)
	@echo '#include "nifticdf.h"' >> $(BRIDGING_HEADER)

xcodebuild:
		xcodebuild -project $(XCODE_PROJECT) -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIGURATION) -derivedDataPath $(DERIVED_DATA) build
	
app:
	@echo "App build is ready at $(DERIVED_DATA)/Build/Products/$(XCODE_CONFIGURATION)/$(PROJECT_NAME).app"

install:
	ditto $(DERIVED_DATA)/Build/Products/$(XCODE_CONFIGURATION)/$(PROJECT_NAME).app /Applications/$(PROJECT_NAME).app
	open /Applications/$(PROJECT_NAME).app

clean:
	rm -rf $(DERIVED_DATA)
	rm -rf $(NIFTI_CLIB_DIR)
	rm -rf $(LIB_DEST_DIR)
	rm -rf $(ZLIB_DIR)
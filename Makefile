APP_NAME = TodoBar
BUILD_DIR = .build/release
DIST = dist/$(APP_NAME).app
INSTALL_DIR = /Applications

# The Command Line Tools ship swift-testing, but SwiftPM doesn't find it on its
# own (Xcode does). Point the compiler and linker at it when only the CLT is active.
CLT = /Library/Developer/CommandLineTools
CLT_FRAMEWORKS = $(CLT)/Library/Developer/Frameworks
ifeq ($(shell xcode-select -p 2>/dev/null),$(CLT))
TEST_FLAGS = -Xswiftc -F -Xswiftc $(CLT_FRAMEWORKS) \
	-Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
	-Xlinker -F -Xlinker $(CLT_FRAMEWORKS) \
	-Xlinker -rpath -Xlinker $(CLT_FRAMEWORKS) \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/usr/lib
endif

.PHONY: build test bundle install run clean

build:
	swift build -c release

test:
	swift test $(TEST_FLAGS)

bundle: build
	rm -rf $(DIST)
	mkdir -p $(DIST)/Contents/MacOS $(DIST)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(DIST)/Contents/MacOS/$(APP_NAME)
	cp bundle/Info.plist $(DIST)/Contents/Info.plist
	codesign --force --deep -s - $(DIST)

install: bundle
	@pkill -x $(APP_NAME) 2>/dev/null || true
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	ditto $(DIST) "$(INSTALL_DIR)/$(APP_NAME).app"
	open "$(INSTALL_DIR)/$(APP_NAME).app"

run: bundle
	$(DIST)/Contents/MacOS/$(APP_NAME)

clean:
	rm -rf .build dist

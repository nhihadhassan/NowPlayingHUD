# NowPlayingHUD — build system
#
# This machine has only Xcode's Command Line Tools installed (no full Xcode.app), so
# `xcodebuild` isn't available here. SwiftPM (`swift build`) is the actual source of truth for
# compiling; this Makefile's job is everything Xcode would otherwise do for you: assembling a
# real, launchable .app bundle (Info.plist, icon, code signature) around the SwiftPM binary.
#
# If you do have Xcode installed, `project.yml` (via `xcodegen generate`) produces a normal
# .xcodeproj you can open, build, and run from Xcode instead — see README "Building".

APP_NAME := NowPlayingHUD
BUNDLE_ID := com.nowplayinghud.app
APP_VERSION := 1.0.0
APP_BUILD := 1

CONFIGURATION := release
BUILD_DIR := .build
APP_BUNDLE := build/$(APP_NAME).app
EXECUTABLE := $(BUILD_DIR)/$(CONFIGURATION)/$(APP_NAME)

.PHONY: all build app run test icon clean install

all: app

# Compiles via SwiftPM only — no bundle, no signing. Fast inner loop while iterating.
build:
	swift build -c $(CONFIGURATION)

# Assembles build/NowPlayingHUD.app: the compiled binary plus Info.plist, the app icon, and an
# ad-hoc code signature (see README "Gatekeeper and signing" for what that does and doesn't mean).
app: build icon
	@echo "==> Assembling $(APP_BUNDLE)"
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(EXECUTABLE)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@sed \
		-e 's/@APP_NAME@/$(APP_NAME)/g' \
		-e 's/@BUNDLE_ID@/$(BUNDLE_ID)/g' \
		-e 's/@APP_VERSION@/$(APP_VERSION)/g' \
		-e 's/@APP_BUILD@/$(APP_BUILD)/g' \
		Resources/Info.plist.in > "$(APP_BUNDLE)/Contents/Info.plist"
	@if [ -f Resources/AppIcon.icns ]; then \
		cp Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"; \
	fi
	@echo "==> Ad-hoc code signing"
	@codesign --force --deep --sign - \
		--entitlements Resources/NowPlayingHUD.entitlements \
		--options runtime \
		"$(APP_BUNDLE)"
	@echo "==> Built $(APP_BUNDLE)"

# Regenerates Resources/AppIcon.icns from Tools/GenerateIcon.swift. Only re-runs when the
# generator script changed or the .icns doesn't exist yet — the icon rarely needs regenerating.
icon: Resources/AppIcon.icns

Resources/AppIcon.icns: Tools/GenerateIcon.swift
	@echo "==> Generating app icon"
	@rm -rf Resources/AppIcon.iconset
	@swift Tools/GenerateIcon.swift Resources/AppIcon.iconset
	@iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
	@rm -rf Resources/AppIcon.iconset

# Builds (if needed) and launches the assembled .app, the same way double-clicking it in Finder
# would — not `swift run`, so the LSUIElement/menu-bar/Dock behavior is exercised for real.
run: app
	open "$(APP_BUNDLE)"

# See Tests/NowPlayingHUDKitTests/MiniTest.swift for why this is `swift run` rather than
# `swift test` on this machine.
test:
	swift run NowPlayingHUDKitTests

clean:
	rm -rf $(BUILD_DIR) build Resources/AppIcon.icns Resources/AppIcon.iconset

# Copies the built app into /Applications. Optional — running straight from build/ works fine.
install: app
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "==> Installed to /Applications/$(APP_NAME).app"

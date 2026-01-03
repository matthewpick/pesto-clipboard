.PHONY: build build-debug test clean install dmg

PROJECT_NAME = PestoClipboard
APP_NAME = Pesto Clipboard
PROJECT_DIR = PestoClipboard
BUILD_DIR = build
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "dev")
DMG_NAME = PestoClipboard-$(VERSION).dmg

build:
	xcodebuild -project $(PROJECT_DIR)/$(PROJECT_NAME).xcodeproj \
		-scheme $(PROJECT_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build

build-debug:
	xcodebuild -project $(PROJECT_DIR)/$(PROJECT_NAME).xcodeproj \
		-scheme $(PROJECT_NAME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		build

test:
	xcodebuild test \
		-project $(PROJECT_DIR)/$(PROJECT_NAME).xcodeproj \
		-scheme $(PROJECT_NAME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR)

install: build
	cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" /Applications/

dmg: build
	@echo "Creating DMG: $(DMG_NAME)"
	@rm -rf dmg-contents $(DMG_NAME)
	@mkdir -p dmg-contents
	@cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" dmg-contents/
	@if command -v create-dmg &> /dev/null; then \
		create-dmg \
			--volname "Pesto Clipboard" \
			--window-pos 200 120 \
			--window-size 600 400 \
			--icon-size 100 \
			--icon "$(APP_NAME).app" 150 185 \
			--hide-extension "$(APP_NAME).app" \
			--app-drop-link 450 185 \
			"$(DMG_NAME)" \
			dmg-contents/ || true; \
	else \
		hdiutil create -volname "Pesto Clipboard" -srcfolder dmg-contents -ov -format UDZO "$(DMG_NAME)"; \
	fi
	@rm -rf dmg-contents
	@echo "Created: $(DMG_NAME)"
	@shasum -a 256 "$(DMG_NAME)"

clean:
	rm -rf $(BUILD_DIR) dmg-contents *.dmg

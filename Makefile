# Makefile — one-command build/test/run for GedReader.
#
# This wraps the three tools the project uses so you never type the long commands:
#   * swift            — builds/tests the GedcomKit engine + GedReaderCore logic (headless).
#   * xcodegen         — (re)generates App/GedReader.xcodeproj from App/project.yml.
#   * xcodebuild       — builds the macOS .app from that project.
#
# Common usage:
#   make            # same as `make help`
#   make test       # run all engine + app-logic unit tests (fast, no Xcode)
#   make run        # build the app and launch it
#   make app        # build the app (Debug) without launching
#   make release    # build the app in Release configuration
#   make clean      # remove all build artifacts and the generated .xcodeproj
#
# CONFIG controls Debug vs Release for app builds (default Debug — faster):
#   make app CONFIG=Release

# ---- Configuration -----------------------------------------------------------

CONFIG       ?= Debug
APP_DIR      := App
PROJECT      := $(APP_DIR)/GedReader.xcodeproj
SCHEME       := GedReader
DERIVED      := $(APP_DIR)/build
APP_PRODUCT  := $(DERIVED)/Build/Products/$(CONFIG)/GedReader.app
DEST         := platform=macOS

# Tools (overridable). Resolved lazily so `make help`/`make test` don't require xcodegen.
SWIFT        := swift
XCODEGEN     := xcodegen
XCODEBUILD   := xcodebuild

.DEFAULT_GOAL := help

# ---- Help (default) ----------------------------------------------------------

.PHONY: help
help:
	@echo "GedReader — make targets:"
	@echo "  make test       Run engine + app-logic unit tests (swift test)"
	@echo "  make build      Build the engine + core libraries (swift build)"
	@echo "  make app        Build the macOS app (CONFIG=$(CONFIG))"
	@echo "  make run        Build the app and launch it"
	@echo "  make release    Build the app in Release configuration"
	@echo "  make generate   Regenerate the Xcode project from App/project.yml"
	@echo "  make clean      Remove build artifacts and the generated .xcodeproj"
	@echo ""
	@echo "  Override config:  make app CONFIG=Release"

# ---- Engine / logic (Swift Package, no Xcode) --------------------------------

.PHONY: build
build:
	$(SWIFT) build

.PHONY: test
test:
	$(SWIFT) test

# ---- App (Xcode project generated from project.yml) --------------------------

# The .xcodeproj is generated; regenerate it whenever project.yml is newer (or it's missing).
# Requires XcodeGen — install with `brew install xcodegen` if this fails.
$(PROJECT): $(APP_DIR)/project.yml
	@command -v $(XCODEGEN) >/dev/null 2>&1 || { \
		echo "error: xcodegen not found. Install it with:  brew install xcodegen"; exit 1; }
	cd $(APP_DIR) && $(XCODEGEN) generate

.PHONY: generate
generate: $(PROJECT)

# Build the .app. Depends on the project existing/up-to-date.
.PHONY: app
app: $(PROJECT)
	$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) \
		-configuration $(CONFIG) -destination '$(DEST)' \
		-derivedDataPath $(DERIVED) build

.PHONY: release
release:
	$(MAKE) app CONFIG=Release

# Build (current CONFIG) then launch the app.
.PHONY: run
run: app
	open "$(APP_PRODUCT)"

# ---- Cleanup -----------------------------------------------------------------

.PHONY: clean
clean:
	rm -rf .build
	rm -rf $(DERIVED)
	rm -rf $(PROJECT)

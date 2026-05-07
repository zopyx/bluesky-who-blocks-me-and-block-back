# BlueskyModeration iOS App — Makefile
#
# Prerequisites:
#   - macOS with Xcode 15+ installed
#   - Xcode Command Line Tools: xcode-select --install
#   - Create the Xcode project first (File → New → Project → iOS App)
#
# Usage:
#   make build    # Build the app for iOS Simulator
#   make sim      # Build, install and launch in iOS Simulator
#   make test     # Run unit tests
#   make clean    # Clean build artifacts

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

PROJECT       = BlueskyModeration.xcodeproj
SCHEME        = BlueskyModeration
DESTINATION   = platform=iOS Simulator,name=iPhone 16,OS=18.5

# ---------------------------------------------------------------------------
# Derived paths
# ---------------------------------------------------------------------------

BUILD_DIR     = build
DERIVED_DATA  = $(BUILD_DIR)/DerivedData

# ---------------------------------------------------------------------------
# Colors for pretty output
# ---------------------------------------------------------------------------

BLUE  = \033[36m
GREEN = \033[32m
RED   = \033[31m
RESET = \033[0m

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

.PHONY: all build sim test clean info

all: build

# Show project configuration
info:
	@echo "$(BLUE)Project:$(RESET)  $(PROJECT)"
	@echo "$(BLUE)Scheme:$(RESET)   $(SCHEME)"
	@echo "$(BLUE)Dest:$(RESET)     $(DESTINATION)"
	@xcodebuild -version

# Build for iOS Simulator
build:
	@echo "$(BLUE)▶ Building $(SCHEME) for simulator...$(RESET)"
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-clonedSourcePackagesDirPath $(BUILD_DIR)/SourcePackages \
		build \
		| xcpretty || xcodebuild \
			-project $(PROJECT) \
			-scheme $(SCHEME) \
			-destination '$(DESTINATION)' \
			-derivedDataPath $(DERIVED_DATA) \
			build
	@echo "$(GREEN)✓ Build succeeded$(RESET)"

# Build and launch in the iOS Simulator
sim: build
	@echo "$(BLUE)▶ Installing to simulator...$(RESET)"
	@# Find the built .app bundle
	APP_PATH=$$(find $(DERIVED_DATA) -name "$(SCHEME).app" -type d | head -n 1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "$(RED)✗ Could not find built .app bundle$(RESET)"; \
		exit 1; \
	fi; \
	echo "$(BLUE)  Found: $$APP_PATH$(RESET)"
	@echo "$(BLUE)▶ Booting simulator (if needed)...$(RESET)"
	@xcrun simctl boot "iPhone 15" 2>/dev/null || true
	@open -a Simulator
	@sleep 2
	@echo "$(BLUE)▶ Installing app...$(RESET)"
	xcrun simctl install booted "$$APP_PATH"
	@echo "$(BLUE)▶ Launching app...$(RESET)"
	xcrun simctl launch booted "com.blueskymoderation.$(SCHEME)" || \
	xcrun simctl launch booted "$$(basename "$$APP_PATH" .app)"
	@echo "$(GREEN)✓ App launched in Simulator$(RESET)"

# Run unit tests
test:
	@echo "$(BLUE)▶ Running tests for $(SCHEME)...$(RESET)"
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-clonedSourcePackagesDirPath $(BUILD_DIR)/SourcePackages \
		test \
		| xcpretty --report junit --output $(BUILD_DIR)/test-results.xml || \
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		test
	@echo "$(GREEN)✓ Tests completed$(RESET)"

# Clean build artifacts
clean:
	@echo "$(BLUE)▶ Cleaning build artifacts...$(RESET)"
	rm -rf $(BUILD_DIR)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	@echo "$(GREEN)✓ Clean complete$(RESET)"

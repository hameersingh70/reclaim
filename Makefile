.PHONY: all build test app run clean icon help

all: build

help:
	@echo "⚡ Reclaim Build System"
	@echo "  make build    - Compile release binary with SwiftPM"
	@echo "  make test     - Run full test suite (158 tests)"
	@echo "  make app      - Assemble and codesign Reclaim.app desktop bundle"
	@echo "  make run      - Launch Reclaim.app desktop application"
	@echo "  make icon     - Regenerate AppIcon.icns from CoreGraphics script"
	@echo "  make clean    - Remove build artifacts and packaged app"

build:
	swift build -c release

test:
	swift run ReclaimTests

app:
	./scripts/bundle_app.sh

run: app
	open Reclaim.app

icon:
	./scripts/generate_app_icon.swift

clean:
	swift package clean
	rm -rf .build Reclaim.app

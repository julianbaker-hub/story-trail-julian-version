SHELL := /bin/zsh

.PHONY: setup-hooks format lint test check concepts concepts-check

setup-hooks:
	git config core.hooksPath .githooks

format:
	xcrun swift-format format --in-place --recursive StoryTrail StoryTrailTests StoryTrailWidgets

lint:
	xcrun swift-format lint --strict --recursive StoryTrail StoryTrailTests StoryTrailWidgets

test:
	@simulator_id="$${SIMULATOR_ID:-$$(xcrun simctl list devices available | sed -nE 's/^[[:space:]]*iPhone.*\(([0-9A-F-]{36})\).*/\1/p' | head -n 1)}"; \
	if [[ -z "$$simulator_id" ]]; then \
		echo "No available iPhone simulator found. Set SIMULATOR_ID to a valid simulator UDID." >&2; \
		exit 1; \
	fi; \
	xcodebuild -project StoryTrail.xcodeproj -scheme StoryTrail \
		-sdk iphonesimulator -destination "platform=iOS Simulator,id=$$simulator_id" \
		-derivedDataPath "$${DERIVED_DATA_PATH:-DerivedData-quality}" \
		test CODE_SIGNING_ALLOWED=NO

check: lint test

concepts:
	@echo "Concept library: http://localhost:8000"
	python3 -m http.server 8000 --directory docs/concepts

concepts-check:
	python3 docs/concepts/check.py

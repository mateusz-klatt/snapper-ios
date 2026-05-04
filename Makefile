.PHONY: setup build test coverage archive clean check-all

DEVELOPMENT_TEAM ?=
PRODUCT_BUNDLE_IDENTIFIER ?= com.example.snapper
SIMULATOR ?= iPhone 17 Pro
SIMULATOR_OS ?= 26.2
DESTINATION = platform=iOS Simulator,name=$(SIMULATOR),OS=$(SIMULATOR_OS)
COVERAGE_RESULT_BUNDLE = build/test-results.xcresult
COVERAGE_REPORT = build/sonarqube-generic-coverage.xml
# Vendored from SonarSource/sonar-scanning-examples@bcf43b3b — verified at
# build time so a tampered script can't run against TestFlight artifacts.
XCCOV_SCRIPT_SHA256 = eccc3e2f3b7a67dab74fdc4b2de9a888a9f86e0ede2856d7d55de095ba488d63

setup:
	@command -v xcodegen >/dev/null 2>&1 || (echo "xcodegen not installed; run: brew install xcodegen" && exit 1)
	xcodegen generate

build: setup
	xcodebuild -scheme Snapper -destination '$(DESTINATION)' build

test: setup
	xcodebuild -scheme Snapper -destination '$(DESTINATION)' test

coverage: setup
	rm -rf $(COVERAGE_RESULT_BUNDLE)
	mkdir -p build
	xcodebuild -scheme Snapper -destination '$(DESTINATION)' \
		-resultBundlePath $(COVERAGE_RESULT_BUNDLE) \
		-enableCodeCoverage YES test
	@test -x scripts/xccov-to-sonarqube-generic.sh || \
		(echo "Vendored converter missing at scripts/xccov-to-sonarqube-generic.sh"; exit 1)
	@echo "$(XCCOV_SCRIPT_SHA256)  scripts/xccov-to-sonarqube-generic.sh" | shasum -a 256 -c -
	scripts/xccov-to-sonarqube-generic.sh $(COVERAGE_RESULT_BUNDLE) > $(COVERAGE_REPORT)

check-all: build test

archive: setup
	@test -n "$(DEVELOPMENT_TEAM)" || (echo "Set DEVELOPMENT_TEAM env var (your Apple Developer team)" && exit 1)
	xcodebuild -scheme Snapper -configuration Release \
		-archivePath build/Snapper.xcarchive \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
		PRODUCT_BUNDLE_IDENTIFIER=$(PRODUCT_BUNDLE_IDENTIFIER) \
		archive

clean:
	rm -rf build/ Snapper.xcodeproj/

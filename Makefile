.PHONY: help doctor setup build test release ios clean check-localization

ifeq ($(origin LANG),command line)
HELP_LANGUAGE := $(LANG)
else
HELP_LANGUAGE := en
endif

help:
	@HELP_LANGUAGE="$(HELP_LANGUAGE)" sh scripts/help.sh

doctor:
	xcode-select -p
	xcodebuild -version
	xcrun swift --version
	xcodebuild -showsdks

setup: doctor
	$(MAKE) build
	$(MAKE) test

build:
	xcrun swift build

test:
	xcrun swift test

release:
	xcrun swift build -c release

ios:
	xcodebuild -scheme SwiftNetPulse -destination 'generic/platform=iOS' -derivedDataPath .build/xcode-ios CODE_SIGNING_ALLOWED=NO build

clean:
	xcrun swift package clean

check-localization:
	python3 scripts/check-localization.py
	python3 -m unittest discover -s Tests/LocalizationChecks -v

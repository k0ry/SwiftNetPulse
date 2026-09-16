.PHONY: help doctor setup build test release ios clean

help:
	@echo "make setup   — проверить инструменты, собрать пакет и запустить тесты"
	@echo "make doctor  — показать версии Xcode, Swift и доступные SDK"
	@echo "make build   — debug-сборка для macOS"
	@echo "make test    — тесты для macOS"
	@echo "make release — release-сборка для macOS"
	@echo "make ios     — сборка для iOS без подписи"
	@echo "make clean   — очистить артефакты SwiftPM"

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

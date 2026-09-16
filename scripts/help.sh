#!/bin/sh
set -eu

language="${HELP_LANGUAGE:-en}"
case "$language" in
  ru|ru-*|ru_*) language=ru ;;
  en|en-*|en_*) language=en ;;
  *) language=en ;;
esac

if [ "$language" = "ru" ]; then
  cat <<'EOF'
Команды разработки SwiftNetPulse:

  make setup               — проверить инструменты, собрать пакет и запустить тесты
  make doctor              — показать версии Xcode, Swift и доступные SDK
  make build               — debug-сборка для macOS
  make test                — тесты для macOS
  make release             — release-сборка для macOS
  make ios                 — сборка для iOS без подписи
  make clean               — очистить артефакты SwiftPM
  make check-localization  — проверки документации и строковых ресурсов
  make help                — эта справка (английский по умолчанию)
  make help LANG=ru        — эта справка на русском

Имена команд не переводятся. Неподдерживаемый язык справки даёт английский текст.
EOF
else
  cat <<'EOF'
SwiftNetPulse development commands:

  make setup               — check tools, build the package, and run tests
  make doctor              — show Xcode, Swift, and available SDK versions
  make build               — macOS debug build
  make test                — macOS tests
  make release             — macOS release build
  make ios                 — unsigned iOS build
  make clean               — remove SwiftPM artifacts
  make check-localization  — documentation and string-resource checks
  make help                — this help (English by default)
  make help LANG=ru        — this help in Russian

Command names are not translated. An unsupported help language falls back to English.
EOF
fi

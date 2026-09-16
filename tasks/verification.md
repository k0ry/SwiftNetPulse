# Localization implementation evidence

Recorded 16 September 2026. Commands were run on Apple Silicon, Xcode 26.4
(17E192), Apple Swift 6.3. Nothing was published or pushed.

## Task 1 — contracts and English fixtures

Files: `docs/LOCALIZATION.md`, `docs/translations.json`,
`Tests/SwiftNetPulseTests/LogFormatterTests.swift`,
`Tests/SwiftNetPulseTests/Fixtures/english-report-success.txt`.

Inventory, presentation API, failure metadata, traceroute companion, fallback
rules, and glossary are in `docs/LOCALIZATION.md`. English success-report
fixture matches `LogFormatter` default output
(`testEnglishSuccessFixtureMatchesBaseline`).

## Tasks 2–5 — bilingual docs and workflow (checkpoint A)

Root guides are English: `README.md`, `DEVELOPMENT.md`, `LICENSE`,
`LICENSING.md`. Russian counterparts live under `docs/ru/` with language
navigation. The public license is CC BY 4.0 in `LICENSE`. Commercial and
noncommercial drafts were removed. `docs/translations.json` maps pages and
source SHA-256 (LF-normalized).

`python3 scripts/check-localization.py` — localization checks passed.

## Task 6 — resources and resolver

`Package.swift` sets `defaultLocalization: "en"` and processes
`Sources/SwiftNetPulse/Resources`. `Localization.swift` loads `en.lproj` /
`ru.lproj` from `Bundle.module`, resolves tags to `en`/`ru`, and never mutates
process locale. `LocalizationTests` cover L01–L08 (default English table,
explicit en/ru, ru-RU/en-GB, unsupported/empty, system preferences, missing ru
key, missing English key, concurrent contexts).

## Tasks 7–8b — typed failures

Additive `ProbeStage` / `ProbeFailureMetadata` on `ProbeResult` and
`ProbeFailure`. Live DNS/TCP/HTTP/TLS populate metadata. `LogFormatter` no
longer classifies by searching “DNS”/“TCP” in strings. `TransportErrorMapper`
maps known `URLError` codes; unknown codes use domain/code plus `rawDetail`.
`TracerouteDetails` is a companion value; `traceroute(to:)` still returns
`TracerouteResult`. `LegacyClientCompileTests` compiles old switches and
constructors.

`swift test --filter FailureMetadataTests` — 7 tests, 0 failures.
`swift test --filter TracerouteTests` — 8 tests, 0 failures.

## Tasks 9–11 — rendering and monitor language (checkpoint B)

`DiagnosisReport.localizedLog(using:)`, `TracerouteResult.localizedLog(using:)`,
`ConnectionMonitorError.localizedDescription(using:)`. `check().log` uses the
monitor’s immutable `ReportLocalization`. `init(endpoints:)` remains English.
Two monitors with `.english` / `.russian` produce independent logs and the same
event semantics. English and Russian full-report fixtures reviewed.

`swift test --filter LogFormatterTests` — 9 tests, 0 failures.
`swift test --filter CheckTests` — 7 tests, 0 failures.
`swift test --filter MonitoringTests` — 3 tests, 0 failures (M03).

## Task 12 — help

`make help` English; `make help LANG=ru` Russian; `make help LANG=de` English
fallback. Command names unchanged. `scripts/help.sh`; Makefile uses
`origin LANG,command line` so the process `LANG` locale does not switch help.

## Tasks 13–14 — checks, CI, consumer

`scripts/check-localization.py` plus
`Tests/LocalizationChecks/test_checks.py` (9 tests: missing key, placeholder
mismatch, broken link, stale digest, missing DRAFT, parser). CI:
`.github/workflows/validation.yml` on `macos-latest` runs the same local
commands. GitHub-hosted runner image was not executed here.

`sh scripts/check-localization-consumer.sh` — `consumer resource lookup succeeded`.
`xcrun swift build -c release` — build complete (existing Swift 6 Sendable
warnings only).
`xcodebuild -scheme SwiftNetPulse -destination 'generic/platform=iOS' … build`
— **BUILD SUCCEEDED**; `en.lproj` and `ru.lproj` copied into
`SwiftNetPulse_SwiftNetPulse.bundle`.

## Tasks 15–16 — API docs and final matrix

English comments on `ConnectionMonitor`, `ReportLocalization`,
`DiagnosisReport.localizedLog`, `traceroute` / `tracerouteDetails`.
`docs/API.md` and `docs/ru/API.md` include language navigation and compatibility
notes. Translator workflow remains in `docs/LOCALIZATION.md`.

`xcrun swift test` — 62 tests, 0 failures.

## Scenario matrix

| ID | Result | Where |
| --- | --- | --- |
| L01 | Pass | Default monitor / `.english` stays English |
| L02 | Pass | LocalizationTests explicit en/ru |
| L03 | Pass | ru-RU / en-GB resolve to base tables |
| L04 | Pass | unsupported/empty → English |
| L05 | Pass | system prefs `[zz-XX, ru-RU]` → ru |
| L06 | Pass | missing ru key → English text, no key leak |
| L07 | Pass | missing English key → `An error occurred.`; checker fails extra/missing keys |
| L08 | Pass | concurrent en/ru titles isolated |
| L09 | Pass | en labels + ru_RU numbers (`6,0 ms`) |
| R01 | Pass | english/russian success fixtures |
| R02 | Pass | typed stage controls DNS/TCP/HTTP labels |
| R03 | Pass | legacy “DNS and TCP” text not reclassified |
| R04 | Pass | rule mismatch + anyData 404 tests unchanged |
| R05 | Pass | empty/binary/Unicode body tests |
| R06 | Pass | known path/VPN labels; unknown token preserved |
| R07 | Pass | rerender does not call prober; stored log unchanged |
| R08 | Pass | known/unknown URLError mapping |
| R09 | Pass | German OS detail labelled raw |
| T01 | Pass | hop labels, timeout `*`, empty list |
| T02 | Pass | socket/DNS/IPv4-only typed reasons |
| T03 | Pass | opaque legacy unavailable string retained |
| M01 | Pass | `init(endpoints:)` English |
| M02 | Pass | two monitors, independent languages |
| M03 | Pass | existing MonitoringTests |
| C01 | Pass | LegacyClientCompileTests + consumer exhaustive switch |
| C02 | Pass | consumer script |
| C03 | Pass | debug/release/iOS resource bundle |
| D01 | Pass | checker markdown links |
| D02–D05 | Pass | checker unit tests + real tree |
| D06 | Pass | paired examples; consumer compiles |
| H01 | Pass | make help / LANG=ru / LANG=de |

## Compatibility and remaining limits

- Source compatibility: existing enum cases, `init(endpoints:)`, and defaulted
  model initializers compile. No ABI promise.
- Live `ProbeOutcome.transportFailure(String)` is English owned text; OS text is
  `rawDetail`. Legacy client-constructed strings stay opaque.
- License drafts remain drafts. Controlling-language proposal is not a contract.
- ICMP ping, cancellation, networking algorithms, and Swift language mode were
  not changed. Existing Swift 6 Sendable warnings remain.
- iOS Simulator / device tests and a Swift 5.9-only toolchain were not run.
- GitHub Actions was added but not executed on a hosted runner.

## Commands actually run

```
python3 scripts/check-localization.py          # passed
python3 -m unittest discover -s Tests/LocalizationChecks -v  # 9 passed
xcrun swift test                               # 62 passed
xcrun swift build -c release                   # complete
xcodebuild -scheme SwiftNetPulse -destination 'generic/platform=iOS' \
  -derivedDataPath .build/xcode-ios CODE_SIGNING_ALLOWED=NO build  # succeeded
sh scripts/check-localization-consumer.sh      # consumer-ok
make help ; make help LANG=ru ; make help LANG=de
```

# Multilingual implementation checklist

All tasks completed 16 September 2026. English is canonical; initial translations are English/Russian.
This file is an engineering worklist, not a translated public guide.

## 1. Freeze localization and compatibility contracts (M)
Description: Inventory owned strings and define explicit language/fallback/error-metadata APIs.
Acceptance:

- [x] Inventory covers docs, logs, errors, help.
- [x] Legacy enum/initializer compatibility is specified.
- [x] Default English fixtures captured.
Verification: review existing clients; run current tests; check English fixtures.
Dependencies: none.
Files: docs/LOCALIZATION.md, docs/translations.json, Tests/SwiftNetPulseTests/LogFormatterTests.swift.

## 2. English-first getting started and development guides (M)
Description: Make root guides English and retain complete Russian counterparts.
Acceptance:

- [x] Both pages exist in both languages.
- [x] Paired language links work.
- [x] Commands/examples match.
Verification: local link check and run documented build/test commands.
Dependencies: 1.
Files: README.md, DEVELOPMENT.md, docs/ru/README.md, docs/ru/DEVELOPMENT.md.

## 3. Translate license status and licensing guide (M)
Description: Translate root status/guide to English, preserve Russian versions and all unresolved fields.
Acceptance:

- [x] Draft status retained.
- [x] No invented owner/contact.
- [x] Canonical/translation relationship clearly proposed.
Verification: side-by-side semantic and placeholder review.
Dependencies: 1.
Files: LICENSE, LICENSING.md, docs/ru/LICENSE.md, docs/ru/LICENSING.md.

## 4. Translate both license drafts (M)
Description: Produce English drafts and corresponding informational Russian translations.
Acceptance:

- [x] Single public license is CC BY 4.0; commercial and noncommercial drafts removed.
- [x] English LICENSE is the legal code; Russian page is informational.
Verification: localization checks; link review.
Dependencies: 3.
Files: LICENSE, LICENSING.md, docs/ru/LICENSE.md, docs/ru/LICENSING.md.

## 5. Translation maintenance workflow (M)
Description: Record source revisions/digests, glossary and stale-translation handling.
Acceptance:

- [x] Every public page mapped.
- [x] Translator instructions in en/ru.
- [x] Adding a language requires no duplicated code API.
Verification: simulate changed source digest; review glossary and navigation.
Dependencies: 2, 4.
Files: docs/LOCALIZATION.md, docs/ru/LOCALIZATION.md, docs/translations.json.

## Checkpoint A
- [x] Documentation coverage and links complete; licensing drafts preserved.
- [x] Review proposed public API contract before runtime implementation.

## 6. Package localization resources and resolver (M)
Description: Add explicit instance-scoped language lookup with English fallback.
Acceptance:

- [x] en/ru lookup works.
- [x] Unsupported/missing-key fallback works.
- [x] Concurrent selections are isolated.
Verification: resolver tests including ru-RU, unsupported language, missing key and OS-independent default.
Dependencies: 1.
Files: Package.swift, Sources/SwiftNetPulse/Localization.swift, Resources/en.lproj/Localizable.strings, Resources/ru.lproj/Localizable.strings (under Sources/SwiftNetPulse), Tests/SwiftNetPulseTests/LocalizationTests.swift.

## 7. Typed probe failure metadata (M)
Description: Separate DNS/TCP failure classification from human-readable messages using the contract from task 1.
Acceptance:

- [x] Existing source initializers/cases compile.
- [x] Typed metadata propagates into failures.
- [x] Legacy raw strings have documented fallback.
Verification: new metadata tests plus existing TCP and monitoring tests; compile old-client fixture.
Dependencies: 1.
Files: Sources/SwiftNetPulse/Models.swift, Sources/SwiftNetPulse/EndpointProber.swift, Sources/SwiftNetPulse/LogFormatter.swift, Tests/SwiftNetPulseTests/FailureMetadataTests.swift.

## 8a. HTTP error metadata (M)
Description: Map URLSession failures to stable domain/code metadata with optional raw system detail.
Acceptance:

- [x] Known codes have localized-summary keys; unknown codes have generic fallback.
- [x] OS text is not used to classify failure.
- [x] Old HTTP/probe consumers continue to compile.
Verification: R08/R09 plus existing HTTPProbeTests.
Dependencies: 7.
Files: Sources/SwiftNetPulse/HTTPProbe.swift, Sources/SwiftNetPulse/EndpointProber.swift, Tests/SwiftNetPulseTests/FailureMetadataTests.swift.

## 8b. Additive detailed traceroute result (M)
Description: Add a companion detailed result and internal trace path, preserving the public legacy enum unchanged.
Acceptance:

- [x] Old exhaustive switches still compile.
- [x] Typed unavailable metadata survives the detailed path and check() report.
- [x] Legacy traceroute() remains an adapter returning the existing enum.
Verification: C01, T02/T03, old constructors, protocol doubles and trace-on-check tests.
Dependencies: 7, 8a.
Files: Sources/SwiftNetPulse/Models.swift, Sources/SwiftNetPulse/PathTrace.swift, Sources/SwiftNetPulse/EndpointProber.swift, Tests/SwiftNetPulseTests/TracerouteTests.swift, Tests/SwiftNetPulseTests/TestSupport.swift.

## 9. Localize diagnosis report rendering (M)
Description: Render structured results with chosen language/locale and retain default English behavior.
Acceptance:

- [x] All report labels/statuses owned by library translated.
- [x] No logic searches translated text.
- [x] Rerendering needs no network.
Verification: en/ru report fixtures, units/decimal locale tests, unchanged data and English compatibility tests.
Dependencies: 6, 8b.
Files: Sources/SwiftNetPulse/LogFormatter.swift, Sources/SwiftNetPulse/Models.swift, both Localizable.strings files, Tests/SwiftNetPulseTests/LogFormatterTests.swift.

## 10. Localize standalone errors and traceroute output (M)
Description: Add localized error/trace presentation with explicit selection and safe unknown-error handling.
Acceptance:

- [x] Every owned error and trace label translated.
- [x] System details identified as raw.
- [x] Legacy trace.log defaults to English.
Verification: en/ru error/trace fixtures; unknown legacy strings preserved; timeout hop formatting.
Dependencies: 9.
Files: Sources/SwiftNetPulse/Models.swift, Sources/SwiftNetPulse/LogFormatter.swift, both Localizable.strings files, Tests/SwiftNetPulseTests/TracerouteTests.swift.

## 11. Expose monitor language configuration (M)
Description: Wire immutable presentation options into newly generated reports and expose the additive detailed traceroute entrypoint; document standalone rendering.
Acceptance:

- [x] Existing init remains compatible.
- [x] Two monitors can use different languages.
- [x] Examples include English default and explicit Russian.
Verification: monitor tests with deterministic doubles and old-client compile check.
Dependencies: 10.
Files: Sources/SwiftNetPulse/ConnectionMonitor.swift, Tests/SwiftNetPulseTests/CheckTests.swift, README.md, docs/ru/README.md.

## Checkpoint B
- [x] All existing and localization tests pass; no global locale mutation.
- [x] API compatibility, English default and translation completeness reviewed.

## 12. Localize development help (S)
Description: English help by default; explicit Russian help without changing command names.
Acceptance:

- [x] make help is English.
- [x] make help LANG=ru is Russian.
- [x] Unsupported language falls back to English.
Verification: run all three help variants; verify commands remain unchanged.
Dependencies: 5.
Files: Makefile, scripts/help.sh (if separation is useful).

## 13. Translation checks and macOS CI (M)
Description: Automate link, key, placeholder, source-digest and draft-marker consistency checks.
Acceptance:

- [x] Both docs/resources checked.
- [x] Intentionally broken fixtures are detected.
- [x] Local and CI entrypoints match.
Verification: temporary bad-key/link/placeholder/stale-digest fixtures; real tree passes.
Dependencies: 5, 11, 12.
Files: scripts/check-localization.py, Tests/LocalizationChecks/test_checks.py, Makefile, .github/workflows/validation.yml, docs/translations.json.

## 14. Consumer resource verification and final developer docs (M)
Description: Validate resource loading from a separate SwiftPM consumer and document adding languages.
Acceptance:

- [x] en/ru work in consuming package.
- [x] macOS release and iOS resources build.
- [x] Documentation and revision map synchronized.
Verification: make test, make release, make ios; temporary external consumer smoke test; localization checks.
Dependencies: 13.
Files: scripts/check-localization-consumer.sh, DEVELOPMENT.md, docs/ru/DEVELOPMENT.md, docs/translations.json.

## 15. Public API documentation: monitor and results (M)
Description: Document defaults, localized rendering and compatibility semantics at declarations and in the bilingual API guide.
Acceptance:

- [x] Monitor initializers, report rendering and detailed traceroute methods have English doc comments.
- [x] English/Russian examples compile and describe legacy raw-detail limitations.
- [x] Each guide includes language navigation and current source revision.
Verification: C01/C02/D06; inspect public declarations and guide links.
Dependencies: 11, 13.
Files: Sources/SwiftNetPulse/ConnectionMonitor.swift, Sources/SwiftNetPulse/Models.swift, docs/API.md, docs/ru/API.md, docs/translations.json.

## 16. Document resolver and final acceptance review (M)
Description: Complete localization API comments, synchronize translator/developer guides and execute the final matrix.
Acceptance:

- [x] Language versus numeric locale, fallback and raw-content exceptions are explicit.
- [x] Every matrix row has a recorded passing check or justified limitation.
- [x] Supported document translations are current; no source behavior beyond localization changed.
Verification: all final commands from plan.md; matrix audit and diff review.
Dependencies: 14, 15.
Files: Sources/SwiftNetPulse/Localization.swift, docs/LOCALIZATION.md, docs/ru/LOCALIZATION.md, docs/translations.json, tasks/verification.md (implementation evidence only).

## Checkpoint C
- [x] All acceptance criteria complete and final diff reviewed.
- [x] License drafts have not been finalized; owner/contact decisions remain separate.
- [x] No publish/push performed.


## Test references and task completion records

Detailed scenarios L01–L09, R01–R09, T01–T03, M01–M03, C01–C03,
D01–D06 and H01 are specified in plan.md. Implement only relevant focused tests
per slice; run the complete existing suite at integration gates.

For each completed task, record files changed, tests/commands actually run and their
results, compatibility observations and remaining limitations in tasks/verification.md.
Do not mark planned tests as passed. Runtime tests are not required for translation-only
edits; link, placeholder and semantic checks are required instead.

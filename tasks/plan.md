# Implementation plan: English-first multilingual SwiftNetPulse

Status: implemented 16 September 2026. Evidence: tasks/verification.md.
Initial supported languages: English (`en`, authoritative source) and Russian (`ru`).
Additional languages follow the same workflow; no automatic promise to support all languages.

## Current state

- README.md, DEVELOPMENT.md, LICENSE, LICENSE-NONCOMMERCIAL.md,
  COMMERCIAL-LICENSE.md, LICENSING.md and Makefile help are Russian.
- Swift API identifiers and most runtime messages are English.
- LogFormatter classifies some failures by searching message strings for DNS/TCP.
- HTTPProbe exposes system-localized error.localizedDescription, so reports can mix languages.
- Report/traceroute properties store or return formatted text; structured results also exist.
- SwiftPM has no localized resources or defaultLocalization.
- License documents remain drafts with unresolved ownership/contact/contract fields.

## Language policy

English is the canonical authoring language for documentation, public API comments,
identifiers, development instructions, and default library output. Russian is a complete
first translation for reader-facing documentation and library-generated messages.
Never translate module names, Swift symbols, commands, paths, protocol identifiers,
URLs/IPs, HTTP codes, response bodies, or structured machine values.
Internal task plans, test names, compiler output and tool-generated build logs remain
English or tool-controlled; they are not duplicated as localized project interfaces.

English content changes first. Translations carry a source revision and review status.
Stale translations are labelled with a link to English, not silently treated as current.
Language selectors link to corresponding pages, using English / Русский, not flags.

## Documentation layout

Keep canonical English root files to preserve repository discovery and existing links:

- README.md, DEVELOPMENT.md, LICENSING.md
- LICENSE, LICENSE-NONCOMMERCIAL.md, COMMERCIAL-LICENSE.md
- docs/ru/README.md, docs/ru/DEVELOPMENT.md, docs/ru/LICENSING.md
- docs/ru/LICENSE.md, docs/ru/LICENSE-NONCOMMERCIAL.md,
  docs/ru/COMMERCIAL-LICENSE.md
- docs/LOCALIZATION.md and docs/ru/LOCALIZATION.md: translator workflow and glossary
- docs/translations.json: document mapping, source digest/revision, translation status

Document and resource language coverage are tracked separately. Keep examples functionally
identical across languages; comments and explanations may be translated. Preserve old
root paths; check every relative link after moving Russian copies.
API source documentation is English. Provide a translated usage/API guide in documentation
instead of duplicating Swift declarations or putting bilingual paragraphs on every symbol.

## License translations

Propose English as the controlling text and Russian as an informational translation;
this must be adopted by the rights holder when finalizing the licenses, not inferred from
this plan. Mirror all DRAFT notices, placeholders, versions and dates. Translation is not
permission to finalize ownership, set commercial prices or change license scope.
Any separately executed commercial agreement controls according to its own agreed language
clause. Legal translations require review for equivalence before publication.

## Runtime localization architecture

Use SwiftPM resources: defaultLocalization "en", processed Resources, en.lproj and
ru.lproj Localizable.strings accessed through Bundle.module. Prefer .strings for the
existing Swift tools 5.9 baseline; use .stringsdict only if plural messages require it.
This follows Apple's package localization support, not a custom dependency.

Introduce an explicit immutable presentation configuration: language and formatting locale.
Existing APIs continue to produce English by default. Offer explicit Russian and optional
system-language selection; unsupported language -> English, region tag -> supported base
language, missing key -> English text (never raw key). Do not change global AppleLanguages,
Bundle.main, or process locale. Concurrent monitors may use different languages safely.

Keep legacy report.log and traceroute.log semantics English by default. Add a localized
rendering API over structured results, and optionally a monitor-level presentation setting
for newly generated report.log. Define signatures before editing consumers. Formatting a
stored report again in another language must not rerun network operations. Error cases
without instance configuration retain English LocalizedError descriptions and offer an
explicit localized presentation method.

Before translating failure text, introduce structured failure stage/code/details, retaining
existing public string-based enum cases and initializers through additive optional metadata
and compatibility adapters where feasible. Define propagation through HTTPProbeResult,
ProbeResult, ProbeFailure and traceroute results. Include legacy manually-created results.
Stop deriving behavior from translated text; internal live operations populate typed data.
Unknown legacy/raw errors remain opaque; do not guess or promise to translate arbitrary text.
If compatibility cannot be maintained, document the precise API change before implementation.

Map known URLSession/system error codes to owned localized messages. Preserve domain/code
and optional original detail separately; system detail can retain the OS language and must
be labelled as such. Localize all library-owned DNS/TCP/HTTP/ICMP errors and snapshot labels.
Do not translate payload bytes or hostnames. Define decimals/units per presentation locale;
keep timestamps ISO-8601 UTC and structured durations as numeric seconds. Existing default
English formatting gets regression fixtures before changes.

## Development commands

Command names and diagnostics from Xcode/Swift remain unchanged. Own help text supports
`make help` (English) and `make help LANG=ru`; unknown language falls back to English.
Keep language selection scoped to help presentation rather than exporting a global locale.
Add a documentation/localization check command and a macOS CI check using the same command.

## Delivery order and checkpoints

1. Capture locale/API contracts and an English regression baseline.
2. Translate root getting-started/development docs, preserving Russian counterparts.
3. Translate licensing docs in two small batches and add translation governance.
4. Checkpoint A: complete bilingual documentation, links, placeholders and draft status.
5. Add resource lookup with fallback and concurrent-language tests.
6. Add typed probe failures, then HTTP/ICMP propagation as separate changes.
7. Localize report rendering, then standalone errors and traceroute presentation.
8. Checkpoint B: English regression tests, Russian fixtures, legacy API examples pass.
9. Localize developer help, add translation checks and CI, finish API usage documentation.
10. Checkpoint C: macOS debug/release/tests, iOS resource build and consumer smoke test.

See todo.md for independently verifiable tasks and dependencies.

## Verification and completion criteria

- English and Russian cover every maintained reader-facing page and library-owned message.
- No new untranslated string keys, mismatched placeholders, broken language links or stale
  translations presented as current. Legal draft status and unresolved fields are preserved.
- Locale selection and fallback are deterministic independent of OS language. A report can
  be rendered in English and Russian without changing its data or starting network work.
- Business logic uses typed fields; localized messages are presentation only.
- Existing client code compiles; legacy string-based failures degrade gracefully.
- Resource bundles are present in debug/release and iOS builds; a small consuming package
  checks lookup through Bundle.module rather than just through the test target.
- Baseline 28 tests continue to pass; add meaningful localization-specific tests.
- No deployment/push or unrelated Swift 6 migration is part of this change.

## Risks and decisions

Largest risk: error strings are part of public models. Validate additive design first.
Translation drift: source digest tracks changes but human review is needed for semantics.
System errors and arbitrary user content cannot be guaranteed to use the selected language.
Legal equivalence and controlling-language provisions need rights-holder/legal review;
localization must not turn existing drafts into effective contracts.
Assumption for review: initial languages are en + ru, default output is explicitly English,
and root documents stay canonical. Extra languages can be selected later without redesign.

## Primary technical references

- Apple: https://developer.apple.com/documentation/xcode/localizing-package-resources
- SwiftPM manifest API: https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html

Consulted 2026-09-16: localized package resources require a default localization and use
Bundle.module. Explicit per-instance language selection/fallback above is a project design,
not a guarantee provided by default bundle language selection.

## Detailed implementation specification (revision 2)

This section refines the initial proposal. Where earlier text leaves a choice open,
use the following concrete plan. No source implementation is authorized by this document alone.

### A. Scope and migration inventory

| Surface | English source | Russian equivalent | Validation |
| --- | --- | --- | --- |
| Installation, quick start, examples | README.md | docs/ru/README.md | Links, example parity, compile examples |
| Setup, architecture, limitations | DEVELOPMENT.md | docs/ru/DEVELOPMENT.md | Commands, documented platform limits |
| Licensing overview | LICENSING.md | docs/ru/LICENSING.md | Clause/placeholder review |
| License status | LICENSE | docs/ru/LICENSE.md | Draft markers, references |
| Noncommercial draft | LICENSE-NONCOMMERCIAL.md | docs/ru/LICENSE-NONCOMMERCIAL.md | Legal semantic review |
| Commercial terms draft | COMMERCIAL-LICENSE.md | docs/ru/COMMERCIAL-LICENSE.md | Unresolved fields preserved |
| Translation workflow/glossary | docs/LOCALIZATION.md | docs/ru/LOCALIZATION.md | Source revision, adding-language example |
| API usage and language selection | docs/API.md | docs/ru/API.md | Compiled examples, matching public symbols |
| Swift source API comments | Source declarations | Localized API guide | English docs build/inspection |
| Library-owned runtime messages | en.lproj/Localizable.strings | ru.lproj/Localizable.strings | Complete keys and typed placeholders |
| Development command help | English help table | Russian help table | Captured command output |

Start by recording all keys with owner, context, arguments and examples. Include header/footer,
endpoint labels, network types (wifi/cellular/ethernet/loopback/other/unsatisfied), VPN yes/no,
DNS/TCP failures, TLS/HTTP timings, outcomes, binary preview, ICMP unavailable reasons,
trace start/hops/timeouts and ConnectionMonitorError cases. Stable acronyms remain unchanged.

Root paths remain valid. Relative links in Russian pages must point back two levels for
source/build files; same-language documentation links stay within docs/ru. Do not translate
repository or module name SwiftNetPulse. Existing generic symbol DiagnosisReport is not
renamed as part of localization. Avoid adding a website or documentation generator.

### B. Presentation API contract to prototype in task 1

Suggested API names below are design sketches, not implemented declarations:

- `ReportLocalization`: immutable Sendable value containing requested language and formatting
  locale identifier. `.english` is deterministic; `.russian` selects ru-RU formatting.
- `init(languageIdentifier:localeIdentifier:)`: supports arbitrary tags for future languages.
- `.system(...)`: explicit factory that snapshots preferred languages once, not a shared
  mutable singleton. Tests inject the preference list.
- `DiagnosisReport.localizedLog(using:)`: recomputes presentation from date/snapshot/results;
  leaves stored `log` unchanged and never calls a probe.
- `TracerouteResult.localizedLog(using:)`: localizes trace labels; arbitrary legacy unavailable
  text remains opaque. Detailed trace rendering is handled by the companion result below.
- `ConnectionMonitorError.localizedDescription(using:)`: explicit presentation; Foundation's
  existing `errorDescription` remains English so throwing initialization has a stable default.
- `ConnectionMonitor.init(endpoints:localization:)`: additive overload. Preserve the existing
  `init(endpoints:)` exactly and delegate to the new implementation with `.english`.

All `check()` report.log values use the monitor's immutable configuration. Raw result fields,
ProbeFailure.message and ProbeOutcome.transportFailure(String) remain compatibility/debug
information; add localized presentation methods instead of changing their machine meaning.
When constructing a report with arbitrary custom log text, localizedLog deliberately renders
structured fields rather than translating the supplied free-form log; document this distinction.

Language resolution: exact supported tag -> supported base tag -> English. In explicit system
mode, examine preferred tags in order, then fall back to English. An omitted format locale uses
the resolved language's documented default. An explicit format locale affects numbers only.
A missing requested-language key falls back to the English key. A missing English key fails
validation; runtime still returns a safe English generic message, never a format-string crash.

Use a private resource resolver with test seams for preferences and resource tables. Resolve
the chosen `.lproj` within Bundle.module rather than relying on main-bundle language selection.
Use typed message helpers: translators may reorder numbered placeholders but may not change
argument types or introduce unsupported substitutions. Do not concatenate sentence fragments.

### C. Error representation and source compatibility

Probe failure metadata can be additive optional properties on ProbeResult and ProbeFailure,
with defaulted initializer parameters. Suggested fields: stage, stable reason code, arguments,
optional system domain/code, optional raw detail. Preserve Sendable/Equatable. Test equality
with/without metadata and document that metadata is part of value equality. Raw strings must
not become dictionary keys or the main classification mechanism.

TracerouteResult is currently a public enum with `.hops` and `.unavailable(message: String)`.
Changing that case's associated value, adding a new public case or replacing the enum would
break exhaustive switches. Therefore use a companion detailed result value containing the
legacy TracerouteResult plus optional typed failure metadata. Add `tracerouteDetails(to:...)`
while retaining `traceroute(to:...)` as a legacy adapter returning the unchanged enum.
Internal tracer/prober paths use the detailed value; check() carries trace metadata additively.
A manually constructed legacy `.unavailable(message:)` retains its exact message and receives
only localized surrounding labels. Explain this limitation in both API guides.

Split task 8 into 8a/8b in todo.md to keep HTTP and trace migration reviewable. Prototype old
client exhaustive switches before completing the resource work. Do not promise ABI stability;
the target is source compatibility for SwiftPM consumers. Existing English owned messages
remain stable except specifically documented presentation fixes approved in the contract.

For legacy ProbeOutcome strings, render a generic transport failure with raw detail instead
of heuristically parsing DNS/TCP. For live results, typed stage controls failed-step labels.
A DNS-looking word in an arbitrary message must not misclassify an HTTP failure.

Known URLSession codes (timeout, DNS failure, connection failure, offline, cancelled,
TLS/certificate failure) map to owned message keys. Unrecognized codes use a localized generic
transport message with domain/code. Capture original system detail separately. Do not translate
OS messages through phrase matching, and do not change network success/failure rules.

### D. Formatting guarantees

- English default uses a fixed English numeric locale; Russian uses Russian formatting.
- Durations keep their existing precision (milliseconds, one decimal; hop RTT two decimals).
- Speed keeps existing rounding and underlying bytes/second calculation. Translate unit labels
  with the same numeric values; do not silently switch bytes to bits or milliseconds to seconds.
- Dates stay ISO-8601 UTC for reproducible diagnostics, irrespective of report language.
- Missing values, empty bodies, binary previews and timed-out hops have explicit test cases.
- Response body preview, raw error detail, host/IP, URL and unknown network-type tokens remain
  unchanged. A raw-data section can contain another language by design.
- Keep existing default English report header/footer in the compatibility baseline. Any branding
  change from NETWORK DIAGNOSIS is a separate documented text change, not a localization side effect.

### E. Test matrix and implementation sequence

Write regression/contract tests before modifying existing runtime behavior. For new localization
features, first add the focused failing case, implement it, then run the related suite. Avoid
network-based tests for string lookup; use deterministic fixtures and injected doubles.

| ID | Scenario | Expected result | Suggested test location |
| --- | --- | --- | --- |
| L01 | No language supplied, OS preference Russian | English output | LocalizationTests |
| L02 | Explicit en and ru | Correct language resources | LocalizationTests |
| L03 | ru-RU, en-GB | Supported language resolution | LocalizationTests |
| L04 | Unsupported or empty identifier | Documented English fallback | LocalizationTests |
| L05 | System preferences [unsupported, ru] | Russian selected | LocalizationTests |
| L06 | Missing Russian key | English text, no exposed key | LocalizationTests |
| L07 | Missing English key or bad placeholder | Static check fails; runtime safe fallback | LocalizationTests + checker tests |
| L08 | Concurrent en/ru contexts | No cross-language state leakage | LocalizationTests |
| L09 | Injected numeric locale differs from language | Labels and numbers follow separate settings | LogFormatterTests |
| R01 | Fixed timestamp, all metrics, success | Reviewed full en/ru fixtures | LogFormatterTests |
| R02 | DNS/TCP/HTTP failures with same opaque text | Typed stage decides labels | FailureMetadataTests |
| R03 | Legacy failure containing DNS/TCP words | No inferred stage, original detail preserved | FailureMetadataTests |
| R04 | Rule mismatch, HTTP 404 accepted by anyData | Outcome semantics unchanged | ProbeRuleTests + LogFormatterTests |
| R05 | Nil metrics, empty/binary/Unicode body | Correct omissions and literal preview | LogFormatterTests |
| R06 | Known and unknown path type, VPN true/false/nil | Owned labels translated, unknown value preserved | LogFormatterTests |
| R07 | Rerender saved report twice | Same data, zero probe calls | CheckTests |
| R08 | Known and unknown URLSession errors | Stable code and localized owned summary | FailureMetadataTests |
| R09 | Raw OS detail in another language | Kept separate and identified as raw | FailureMetadataTests |
| T01 | Hops, timeout hop, empty list | en/ru labels and RTT precision | TracerouteTests |
| T02 | Socket/DNS/IPv6 unavailable typed reasons | All owned reasons localized | TracerouteTests |
| T03 | Arbitrary legacy unavailable string | Exact raw string retained | TracerouteTests |
| M01 | Monitor without new parameter | English, old init compiles | CheckTests + consumer fixture |
| M02 | Two monitors with different settings | Independent logs and identical event semantics | CheckTests |
| M03 | failures/events delivery and stop semantics | Existing behavior preserved | MonitoringTests |
| C01 | Existing enum switches and constructors | Old client compiles unchanged | Consumer fixture |
| C02 | External consumer loads resources | en/ru work outside package tests | Consumer smoke script |
| C03 | Debug/release and iOS build | Resource bundles included | Build checks |
| D01 | All paired pages and language links | No broken file/fragment links | Documentation checker |
| D02 | Missing/extra/duplicate key or wrong argument type | Check fails with file/key context | Checker unit tests |
| D03 | Reordered valid numbered placeholders | Check succeeds | Checker unit tests |
| D04 | Changed English source digest | Stale translation detected | Checker unit tests |
| D05 | Removed DRAFT or unresolved legal field mismatch | Check fails | Checker unit tests + manual review |
| D06 | Code examples across languages | Equivalent executable content | Checker + consumer build |
| H01 | Help default / ru / unsupported | en / ru / en | Help command output tests |

Use fixed timestamps, localhost only when exercising existing integration tests, and temporary
fixture directories. Do not require public DNS, actual traceroute permissions or a particular
macOS display language for new localization tests. The existing suite's network-sensitive
cases stay documented; do not weaken their assertions merely to pass localization changes.

Snapshot fixtures require explicit human-readable review of labels and numbers. Do not test
translations by computing expected text through the same resolver being tested. Unit-test
behavior, not one-to-one private function structure. Documentation-only translations need
link/consistency checks, not new XCTest cases.

### F. Translation checker design

Use standard-library tooling where possible; no additional runtime dependency for consumers.
A manifest entry identifies English path, translated path, locale, source SHA-256 and review
status. Hash normalized LF source content; do not include translated files in the English hash.
Keep mappings in one manifest and avoid a manifest that hashes itself. Check English docs
first, finish translation, then explicitly record the reviewed source digest.

Statuses: current / stale / missing. Initial en/ru delivery requires all maintained pages current.
During development, stale pages may remain only with a visible English-source link and warning;
release verification fails for stale supported translations. Digest updates must not silently
mark machine-generated translation as reviewed.

Parse .strings structurally (comments, escapes, multiline content, duplicate keys), not with a
single regex. Validate source/translation key sets and format argument signatures, including
numbered placeholders and literal percent signs. Never execute text extracted from translations.
Check local Markdown file and fragment references, allow explicit external URLs without requiring
network access in CI, and report unsupported Markdown constructs rather than silently passing.
License consistency checks use semantic placeholder IDs mapped to localized display wording;
manual legal equivalence review remains necessary and is not replaced by a string checker.

Proposed commands (to be added during implementation):

```sh
make check-localization
python3 -m unittest discover -s Tests/LocalizationChecks
swift test --filter LocalizationTests
swift test --filter FailureMetadataTests
swift test --filter LogFormatterTests
swift test --filter TracerouteTests
make test
make release
make ios
sh scripts/check-localization-consumer.sh
```

Do not run nonexistent commands during the planning phase. CI runs the same local checks on a
macOS runner. Choose and record an actually available Xcode version when implementing CI;
avoid relying on an unverified Xcode version or fetching tools solely to translate documents.
Baseline warnings about Swift 6 concurrency are existing debt, not acceptance failures introduced
by this project. New compile errors, resource warnings and additional concurrency warnings fail.

### G. Review gates, rollback and scope

Gate 1: assess API sketch against old-client compile fixture and finalize the additive trace
companion approach before modifying production types. If an incompatible change is necessary,
record the precise caller migration and versioning decision instead of silently breaking clients.
Gate 2: documentation links, source-language policy and license draft parity are complete.
Gate 3: resource lookup and typed error tests pass before runtime call sites switch.
Gate 4: full suite plus external consumer/debug/release/iOS checks pass after integration.

Keep each slice reviewable. Documentation can be reverted independently of runtime changes.
Error metadata must land before localized error formatting; never ship localized strings while
classification still depends on their text. Do not mass-replace words in Swift identifiers.
No changes to cancellation semantics, networking algorithms, ICMP packet parsing, copyright
ownership, commercial price, publishing, or Swift language mode are included.

Effort order: documentation/governance is medium; resolver/formatting is medium; additive
error/traceroute compatibility is the largest and most uncertain part. Validate that first.
The engineering checklist is a dependency plan, not a promise of calendar completion time.

### H. Definition of done

- [x] Every surface in the scope table is delivered or explicitly documented as tool/raw content.
- [x] All new public methods have English comments and equivalent en/ru usage examples.
- [x] All L/R/T/M/C/D/H scenarios relevant to implemented behavior are covered and pass.
- [x] No keys or translation fragments leak in user-visible output; system/raw detail is labelled.
- [x] Old public constructors and exhaustive enum switches compile; structured values are stable.
- [x] English and Russian docs are current, navigable and semantically reviewed.
- [x] License drafts remain drafts; controlling-language proposal has not silently become a contract.
- [x] One real external consumer verifies both language bundles; macOS and iOS builds pass.
- [x] Final report states checks run, unsupported platform checks and any remaining known limitations.

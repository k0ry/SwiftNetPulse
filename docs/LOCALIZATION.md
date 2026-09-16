# Localization of SwiftNetPulse

**Language:** [English](LOCALIZATION.md) · [Русский](ru/LOCALIZATION.md)

English is the canonical authoring language for documentation, public API
comments, identifiers, development instructions, and default library output.
Russian is a complete first translation. Additional languages follow this
workflow; there is no automatic promise to support every language.

This file is the localization contract. Runtime types are implemented to match
the signatures below. Identifier names in Swift (`SwiftNetPulse`,
`ConnectionMonitor`, `DiagnosisReport`, commands, paths, URLs, IP addresses,
HTTP status codes, and response bodies) are never translated.

## Inventory

Owned strings live in documentation, `make help`,
`Localizable.strings`, and `LocalizedError` English defaults.

| Surface | English source | Russian equivalent |
| --- | --- | --- |
| Installation and quick start | `README.md` | `docs/ru/README.md` |
| Setup, architecture, limits | `DEVELOPMENT.md` | `docs/ru/DEVELOPMENT.md` |
| Licensing overview | `LICENSING.md` | `docs/ru/LICENSING.md` |
| CC BY 4.0 license | `LICENSE` | `docs/ru/LICENSE.md` |
| This workflow and glossary | `docs/LOCALIZATION.md` | `docs/ru/LOCALIZATION.md` |
| API usage guide | `docs/API.md` | `docs/ru/API.md` |
| Runtime messages | `Sources/SwiftNetPulse/Resources/en.lproj/Localizable.strings` | `…/ru.lproj/Localizable.strings` |
| Development help | `make help` | `make help LANG=ru` |

Library-owned runtime keys (arguments are numbered `%1$@`, `%2$@`):

- Report: `report.title`, `report.date`, `report.network_type`, `report.local_ip`,
  `report.dns_servers`, `report.vpn`, `report.vpn.yes`, `report.vpn.no`,
  `report.finished`
- Endpoint: `endpoint.separator`, `endpoint.url`, `endpoint.host`
- Steps: `dns.resolved`, `dns.resolved_timed`, `dns.failed`, `dns.failed_timed`,
  `tcp.connected`, `tcp.failed`, `https.connect`, `tls.handshake`, `http.status`,
  `http.response`, `timing.total`, `timing.speed`
- Units: `unit.bytes_per_second`, `unit.milliseconds`
- Outcomes: `outcome.success`, `outcome.rule_mismatch`,
  `outcome.transport_failure`
- Body: `body.preview`, `body.binary`
- Trace: `trace.start`, `trace.unavailable`, `trace.hop`, `trace.timeout_marker`,
  `trace.socket`, `trace.dns`, `trace.ipv4_only`
- Path types: `path.wifi`, `path.cellular`, `path.ethernet`, `path.loopback`,
  `path.other`, `path.unsatisfied`
- Errors: `error.empty_endpoints`, `error.invalid_interval`
- Failures: `failure.missing_host`, `failure.dns_failed`,
  `failure.timeout_before_tcp`, `failure.timeout_before_http`,
  `failure.tcp_failed`, `failure.no_http_status`, `failure.non_http_response`,
  `failure.url_timeout`, `failure.url_dns`, `failure.url_connect`,
  `failure.url_offline`, `failure.url_cancelled`, `failure.url_tls`,
  `failure.url_generic`, `failure.generic_transport`
- Raw system text: `raw.system_detail`

Not owned (left unchanged, never used as a dictionary key for classification):

- Hostnames, IPs, URLs, HTTP bodies, user-supplied log strings
- Unknown `NetworkSnapshot.pathType` tokens
- `ProbeOutcome.transportFailure(String)` and
  `TracerouteResult.unavailable(message:)` associated values on values
  constructed by clients
- OS `localizedDescription` captured only as `rawDetail`
- Compiler, SwiftPM, and Xcode diagnostics

## Language resolution

Supported message tables: `en`, `ru`.

1. Exact supported tag (`en`, `ru`).
2. Base language of a regional tag (`ru-RU` → `ru`, `en-GB` → `en`).
3. English.

`ReportLocalization.system(preferredLanguages:localeIdentifier:)` snapshots the
preference list once. It walks the list in order and selects the first supported
language; if none match, English is used. It does not read or write
`AppleLanguages`, `Bundle.main`, or the process locale.

A missing key in the requested language uses the English table. A missing
English key fails `make check-localization`; at runtime the library returns the
hard-coded English sentence `An error occurred.` and never crashes on a format
string. Translators may reorder numbered placeholders and must not change
argument count or types. Literal `%%` is allowed.

## Presentation API

```swift
public struct ReportLocalization: Equatable, Sendable {
    public var languageIdentifier: String
    public var localeIdentifier: String
    public init(languageIdentifier: String, localeIdentifier: String? = nil)
    public static let english: ReportLocalization
    public static let russian: ReportLocalization
    public static func system(
        preferredLanguages: [String],
        localeIdentifier: String?
    ) -> ReportLocalization
}

extension DiagnosisReport {
    public func localizedLog(using localization: ReportLocalization) -> String
}

extension TracerouteResult {
    public func localizedLog(using localization: ReportLocalization) -> String
}

extension TracerouteDetails {
    public func localizedLog(using localization: ReportLocalization) -> String
}

extension ConnectionMonitorError {
    public func localizedDescription(using localization: ReportLocalization) -> String
}

extension ConnectionMonitor {
    public convenience init(endpoints: [Endpoint]) throws
    public convenience init(endpoints: [Endpoint], localization: ReportLocalization) throws
    public func traceroute(to host: String, maxHops: Int) async -> TracerouteResult
    public func tracerouteDetails(to host: String, maxHops: Int) async -> TracerouteDetails
}
```

`init(endpoints:)` is unchanged and delegates to `localization: .english`.
`check().log` uses the monitor's immutable configuration. Two monitors may use
different languages concurrently. Re-rendering a stored report does not probe
the network and does not modify `DiagnosisReport.log`. A custom `log` supplied
to `DiagnosisReport.init` is stored as-is; `localizedLog(using:)` always renders
structured fields.

`errorDescription` for `ConnectionMonitorError` stays English.
`localeIdentifier` affects numbers only. English default numbers use
`en_US_POSIX`. Russian default numbers use `ru_RU`. Dates stay ISO-8601 UTC.

## Failure metadata and source compatibility

Additive optional metadata on `ProbeResult` and `ProbeFailure`:

```swift
public enum ProbeStage: String, Equatable, Sendable {
    case dns, tcp, http, tls, traceroute, unknown
}

public struct ProbeFailureMetadata: Equatable, Sendable {
    public var stage: ProbeStage
    public var reasonCode: String
    public var arguments: [String]
    public var systemDomain: String?
    public var systemCode: Int?
    public var rawDetail: String?
}
```

Existing memberwise initializers keep defaulted new parameters so old call sites
compile. Metadata participates in `Equatable`. Live probes populate typed stage
and reason codes. Classification never searches translated or raw strings for
`DNS` / `TCP`.

`ProbeOutcome.transportFailure(String)` and `ProbeFailure.message` remain
English compatibility/debug text for live results. Legacy values without
metadata keep their original string and render as a generic transport failure
plus raw detail.

`TracerouteResult` cases stay `.hops([TraceHop])` and
`.unavailable(message: String)`. A companion `TracerouteDetails` carries the
legacy enum plus optional typed unavailable metadata.
`traceroute(to:)` is a compatibility adapter; `tracerouteDetails(to:)` is the
detailed entry point. A manually constructed `.unavailable(message:)` keeps that
exact message; surrounding labels localize.

Known `URLError` / `NSURLErrorDomain` codes map to owned keys. Unknown codes use
`failure.url_generic` with domain and numeric code. OS text is stored in
`rawDetail` and labelled as raw when presented.

## Formatting guarantees

- Duration: milliseconds, one decimal (hop RTT: two decimals).
- Speed: same bytes/second calculation and rounding; only the unit label is
  translated. Values are not converted to bits.
- Missing timings are omitted. Empty bodies omit the preview. Non-UTF-8 bodies
  use `body.binary`. Timed-out hops use `trace.timeout_marker`.
- Default English header/footer remain `NETWORK DIAGNOSIS` /
  `DIAGNOSIS FINISHED`.

## Translation workflow

1. Edit English documentation or `en.lproj` first.
2. Update the matching Russian files.
3. Run `make check-localization`.
4. Record the English source SHA-256 (normalized LF) and set status `current`
   in `docs/translations.json`. Do not hash the manifest itself.

Statuses: `current`, `stale`, `missing`. A stale supported translation must
link to the English source and show a warning. Release checks fail while a
supported translation is stale or missing.

License drafts stay drafts. Translation does not fill ownership, contact, price,
or governing-law fields. English is proposed as the controlling legal text and
Russian as an informational translation; the rights holder must adopt that when
finalizing. Placeholders are mapped by semantic ID in `docs/translations.json`.

## Adding a language

1. Copy `en.lproj/Localizable.strings` to `xx.lproj` and translate values.
2. Add `docs/xx/` pages for every mapped document.
3. Register the language and source digests in `docs/translations.json`.
4. Select it with `ReportLocalization(languageIdentifier: "xx")`.

No new Swift API is required for an additional message table.

## Glossary

| English | Russian | Notes |
| --- | --- | --- |
| endpoint | эндпоинт | Public type stays `Endpoint` |
| probe / check | проверка | Method remains `check()` |
| traceroute | traceroute / трассировка | Command-style label may stay |
| hop | хоп | Index and addresses unchanged |
| rule mismatch | несовпадение правила | Outcome label only |
| transport failure | транспортная ошибка | Outcome label only |
| monitoring | мониторинг | `startMonitoring` unchanged |

## Compatibility review notes

- No ABI stability promise; target is source compatibility for SwiftPM clients.
- Exhaustive switches on `TracerouteResult`, `ProbeOutcome`, `ProbeEvent`,
  `ProbeFailureKind`, and `ConnectionMonitorError` must still compile.
- Existing `ConnectionMonitor(endpoints:)` and defaulted model initializers
  must still compile.
- ICMP ping remains out of scope. Networking algorithms, cancellation, and
  Swift language mode are not changed by localization.

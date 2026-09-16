# SwiftNetPulse API usage

**Language:** [English](API.md) · [Русский](ru/API.md)

This guide describes public initialization, diagnosis reports, localized
rendering, and compatibility. Swift identifier names are not duplicated in a
second language on every symbol; source documentation comments are English.

Related pages: [README.md](../README.md), [LOCALIZATION.md](LOCALIZATION.md),
[DEVELOPMENT.md](../DEVELOPMENT.md).

## Default English monitor

```swift
import SwiftNetPulse

let monitor = try ConnectionMonitor(endpoints: [
    Endpoint(url: URL(string: "https://example.test/health")!, rule: .anyData),
])
let report = await monitor.check()
print(report.log) // English labels, POSIX-style numbers
```

`ConnectionMonitor(endpoints:)` is unchanged. It uses `ReportLocalization.english`.
`Foundation.LocalizedError.errorDescription` for `ConnectionMonitorError` stays
English even when a monitor is configured for another language.

## Explicit Russian and independent monitors

```swift
let english = try ConnectionMonitor(
    endpoints: [Endpoint(url: URL(string: "https://example.test/")!, rule: .anyData)],
    localization: .english
)
let russian = try ConnectionMonitor(
    endpoints: [Endpoint(url: URL(string: "https://example.test/")!, rule: .anyData)],
    localization: .russian
)
let englishReport = await english.check()
let russianReport = await russian.check()
// Event and failure publishers keep the same structured semantics.
_ = english.events
_ = russian.failures
```

`ReportLocalization.system(preferredLanguages:localeIdentifier:)` snapshots a
preference list once (inject the list in tests). Unsupported tags fall back to
English. Region tags such as `ru-RU` resolve to the `ru` table.

Language selects message tables. `localeIdentifier` selects numeric formatting
only. Mix them when needed:

```swift
let mixed = ReportLocalization(languageIdentifier: "ru", localeIdentifier: "en_US_POSIX")
print(englishReport.localizedLog(using: mixed))
```

Re-rendering does not run probes and does not change the stored `log`. If a
`DiagnosisReport` was constructed with a custom `log` string, that stored text
is kept; `localizedLog(using:)` still rebuilds from `date`, `snapshot`, and
`results`.

## Traceroute compatibility

```swift
let legacy: TracerouteResult = await monitor.traceroute(to: "example.test")
switch legacy {
case .hops(let hops):
    print(hops.count)
case .unavailable(let message):
    print(message) // raw compatibility string; may be English library text or client text
}

let details: TracerouteDetails = await monitor.tracerouteDetails(to: "example.test")
print(details.localizedLog(using: .russian))
```

Do not add a third public enum case to `TracerouteResult`. A manually created
`.unavailable(message: "custom")` keeps `custom` exactly; only surrounding
labels such as “Traceroute unavailable” are translated. Typed unavailable
reasons from live traces are carried on `TracerouteDetails.unavailableMetadata`
and, during `check()`, on `ProbeResult.tracerouteFailureMetadata`.

## Failure metadata

Live DNS, TCP, HTTP, and TLS failures set `ProbeResult.failureMetadata` and
`ProbeFailure.metadata` with `ProbeStage` and a stable `reasonCode`. Known
`URLError` codes map to owned summaries. The OS `localizedDescription` is stored
in `rawDetail` and printed on a separate “System detail (raw)” line when present.

`ProbeOutcome.transportFailure(String)` remains a compatibility string (English
for live probes). Do not parse it to decide DNS versus TCP; use `stage`.
A legacy result whose message happens to contain “DNS” is not reclassified.

## Errors

```swift
do {
    _ = try ConnectionMonitor(endpoints: [])
} catch let error as ConnectionMonitorError {
    print(error.errorDescription ?? "") // English
    print(error.localizedDescription(using: .russian))
}
```

## What is never translated

Hostnames, IP addresses, URLs, HTTP status numbers, response body bytes,
unknown network-type tokens, and arbitrary client-supplied unavailable
messages. Payload text may be in another language by design.

Source revision for this guide is tracked in
[translations.json](translations.json).

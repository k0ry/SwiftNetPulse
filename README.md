# SwiftNetPulse

**Language:** [English](README.md) · [Русский](docs/ru/README.md)

A Swift package that checks a list of URLs: one-shot diagnosis, periodic error
monitoring through **Combine**, and on-demand route tracing.

ICMP ping is **not** part of the v1 success criteria and is not performed.

## Installation

In the application `Package.swift`:

```swift
.package(path: "../SwiftNetPulse")
```

or by repository URL once the package is published.

Platforms: iOS 15+, macOS 12+.

## Initialization

```swift
import SwiftNetPulse

let monitor = try ConnectionMonitor(endpoints: [
    Endpoint(url: URL(string: "https://skills.example/")!, rule: .anyData),
    Endpoint(
        url: URL(string: "https://api.example/health")!,
        rule: .all([.statusEqual(200), .bodyContains("ok")]),
        timeout: 5,
        traceOnCheck: true
    ),
])
```

One rule per URL. Combine conditions with `.all([...])`.

Reports are English by default. Pass `localization:` for Russian or another
supported table; two monitors can use different languages at the same time:

```swift
let english = try ConnectionMonitor(endpoints: endpoints) // English
let russian = try ConnectionMonitor(endpoints: endpoints, localization: .russian)
let report = await russian.check()
print(report.log)
print(report.localizedLog(using: .english)) // rerender without probing
```

## One-shot `check()`

```swift
let cancellable = monitor.events.sink { event in
    switch event {
    case .success(let result): print("ok", result.httpStatus ?? 0)
    case .failure(let result): print("fail", result.outcome)
    }
}

let report = await monitor.check()
print(report.log)
```

`report.log` is an approximate human-readable report (DNS, TCP, HTTPS, status,
speed, body preview). Success and failure events arrive **as each URL finishes**,
before the full report is returned.

## Periodic monitoring (Combine)

```swift
let failures = monitor.failures.sink { failure in
    print(failure.kind, failure.endpoint.url)
}

try monitor.startMonitoring(every: 30)
// ...
monitor.stopMonitoring()
```

Background monitoring uses the same rules as `check()`. Traceroute is not
started. Only errors (transport or rule mismatch) are published. A successful
404 under `.anyData` is not published on `failures`.

## Traceroute

```swift
let route = await monitor.traceroute(to: "api.example.com")
print(route.log)          // route text
print(route.hopList)      // structured hops
```

Returns a hop list (a hop timeout has no address or RTT) or `.unavailable` if
the ICMP socket cannot be opened. The system `traceroute` binary is not invoked.

In `check()`, a route is added only when the endpoint has `traceOnCheck == true`.

## Measurements

Before payload: DNS, TCP connect, TLS / HTTPS connect.
After: HTTP response time, total, speed = body bytes / response time (when the
body is non-empty and the duration is greater than 0).

## Development

From the repository root on macOS with Xcode installed:

```bash
make setup
```

The command checks tools, builds the package, and runs tests. Additional
commands: `make test`, `make release`, `make ios`, `make help`.
To work in Xcode, open `Package.swift` and select the `SwiftNetPulse` scheme.
The repository directory name is `SwiftNetPulse`; the imported module name is
`SwiftNetPulse`.

Tests alone: `swift test` from the repository root.
Requirements, architecture, and limitations are described in
[DEVELOPMENT.md](DEVELOPMENT.md).
Localization policy and translator workflow:
[docs/LOCALIZATION.md](docs/LOCALIZATION.md).
Public API usage: [docs/API.md](docs/API.md).

## Licensing

SwiftNetPulse is planned to use dual licensing:

- Free use solely for noncommercial purposes under the
  [noncommercial license](LICENSE-NONCOMMERCIAL.md).
- Commercial use, including in paid or monetized applications and internal
  business tools, requires a separate paid license.
  [Draft commercial terms](COMMERCIAL-LICENSE.md).

**The license documents are drafts and do not grant rights:** the rightsholder
must be confirmed, the placeholders filled in, and the final texts adopted.
Contact for purchasing a license: **[CONFIRMED CONTACT — FILL IN]**.
Price and commercial terms are not yet set.

This is a source-available model with a restriction on purpose of use, not
open source. Overall status is in [LICENSE](LICENSE); remaining fields and
sources are in [LICENSING.md](LICENSING.md).

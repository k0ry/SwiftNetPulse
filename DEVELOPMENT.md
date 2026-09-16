# Developing SwiftNetPulse

**Language:** [English](DEVELOPMENT.md) · [Русский](docs/ru/DEVELOPMENT.md)

## Environment

macOS with Xcode and Swift tools 5.9 or newer is required. The manifest uses
Swift language mode 5. Minimum platforms are iOS 15 and macOS 12. Imports of
Darwin, Network, and Combine make the current implementation dependent on Apple
platforms.

There are no third-party packages, CocoaPods, servers, API keys, or environment
variables. A separate Swift version manager is not required: Makefile commands
use the toolchain of the selected Xcode via `xcrun`.

Verified environment 16 September 2026: Apple Silicon, Xcode 26.4 (17E192),
Apple Swift 6.3, SDK macOS/iOS 26.4. After localization: `swift test` 62 tests,
0 failures; `python3 -m unittest discover -s Tests/LocalizationChecks` 9 tests,
0 failures. Debug and release macOS builds, an unsigned iOS build (resource
bundle includes `en.lproj` and `ru.lproj`), and
`scripts/check-localization-consumer.sh` succeeded. Tests were not run on the
iOS Simulator or a physical device. Compatibility with the minimum Swift 5.9 was
not verified separately.

```sh
make setup    # tools, debug build, tests
make release  # optimized macOS build
make ios      # unsigned iOS build, no physical device
make check-localization  # documentation and string-resource checks
```

In Xcode open `Package.swift`, select the `SwiftNetPulse` scheme and My Mac
for tests. To exercise iOS, select an available device or simulator.
Makefile artifacts live in `.build/` and are excluded from Git.

Tests open local TCP/HTTP servers on automatically chosen ports. There are DNS
checks for `.invalid` and a TCP timeout against `192.0.2.1`; those results may
depend on the network environment. A constrained execution environment needs
access to local sockets and the user compiler cache.

Localized message tables are loaded from `Bundle.module` (`en.lproj` and
`ru.lproj`). Default library output is English regardless of the host OS
language. A separate SwiftPM consumer should be used to confirm that resources
load outside this package's test target; see
`scripts/check-localization-consumer.sh`.

To add a language, copy `Sources/SwiftNetPulse/Resources/en.lproj/Localizable.strings`
to a new `xx.lproj`, translate documentation under `docs/xx/`, and register the
language in [docs/translations.json](docs/translations.json). No new Swift API
is required. Details: [docs/LOCALIZATION.md](docs/LOCALIZATION.md).

## Library layout

| Component | Responsibility |
| --- | --- |
| `ConnectionMonitor` | Public API, sequential endpoint walk, Combine events, monitoring timer |
| `Models` and `ProbeRule+Evaluate` | Configuration, results, status and body checks |
| `LiveEndpointProber` | DNS → separate TCP check → HTTP → rule → optional traceroute |
| `DNSResolver`, `TCPProbe`, `HTTPProbe` | System DNS, NWConnection, URLSession, and metrics |
| `LiveNetworkSnapshotProvider` | Network type, local IPv4, DNS servers, VPN heuristic |
| `ICMPPathTracer` | IPv4 ICMP echo with increasing TTL, no external process |
| `LogFormatter` | Text reports and hop formatting |
| `Localization` | Per-instance language lookup with English fallback |

Internal protocols `EndpointProbing`, `PathTracing`, and
`NetworkSnapshotProviding` allow system operations to be replaced in tests.
Tests cover rules, events, timer stop, local HTTP/TCP, formatting, and traceroute
control. A real ICMP route and a TLS handshake are not covered by the existing
tests.

## Limitations and follow-up work

The items below come from reading the code and compiler diagnostics; each
runtime scenario was not reproduced individually.

1. **Swift 6 concurrency.** The compiler warns about mutable-state captures in
   `TCPProbe` and `NetworkSnapshot`, a non-Sendable `ConnectionMonitor`, and
   NSLock use from async tests. Isolation must be defined before enabling Swift
   language mode 6, and test doubles updated.
2. **Timeout and cancellation.** Synchronous `getaddrinfo` is not bounded by the
   endpoint timer; traceroute starts after `timings.total` is computed and can
   increase the real duration of `check()`. `stopMonitoring()` stops the timer
   but does not cancel an in-flight pass or its later events.
3. **Measurements.** The TCP check opens a separate connection. URLSession then
   connects on its own; the displayed `resolvedIP` is not guaranteed to be the
   HTTP connection address. HTTP metrics come from the last transaction,
   including redirects. Speed is computed from body-response time.
4. **Input validation.** Explicit checks are needed for URL scheme, finiteness
   and validity of timeout/interval, and an upper bound on `maxHops`; TTL
   conversions to UInt16/Int32 are not guarded against oversized values.
5. **Traceroute.** The implementation supports IPv4 only, even though
   DNSResolver may return IPv6 first. The ICMP parser and socket behavior on
   real iOS devices need separate verification.
6. **Snapshot and memory.** VPN is inferred from interface names; DNS is read
   from `/etc/resolv.conf`. These are approximate. The HTTP body is kept fully
   in memory with no size limit, although the log shows only the first 240 bytes.

Priority of further work (outside localization): define timeout/cancellation and
event-stream guarantees, add matching tests, then prepare a Swift 6 transition.
Localization must not change those networking semantics.

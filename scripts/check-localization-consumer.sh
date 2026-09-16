#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/swiftnetpulse-consumer.XXXXXX")"
cleanup() { rm -rf "$work"; }
trap cleanup EXIT INT TERM

mkdir -p "$work/Sources/Consumer"

cat > "$work/Package.swift" <<EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftNetPulseConsumer",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(path: "$root"),
    ],
    targets: [
        .executableTarget(
            name: "Consumer",
            dependencies: [
                .product(name: "SwiftNetPulse", package: "SwiftNetPulse"),
            ]
        ),
    ]
)
EOF

cat > "$work/Sources/Consumer/main.swift" <<'EOF'
import Foundation
import SwiftNetPulse

let endpoint = Endpoint(url: URL(string: "https://example.test/health")!, rule: .anyData)
let result = ProbeResult(
    endpoint: endpoint,
    outcome: .success,
    resolvedIP: "1.1.1.1",
    httpStatus: 200,
    body: Data("ok".utf8),
    timings: ProbeTimings(dns: 0.001, tcpConnect: 0.002, total: 0.01)
)
let report = DiagnosisReport(
    date: Date(timeIntervalSince1970: 1_789_560_000),
    snapshot: NetworkSnapshot(
        pathType: "wifi",
        localIPv4: "10.0.0.1",
        dnsServers: ["1.1.1.1"],
        vpnDetected: false
    ),
    results: [result],
    log: "custom stored log"
)

func handle(_ value: TracerouteResult) -> String {
    switch value {
    case .hops(let hops):
        return "hops \(hops.count)"
    case .unavailable(let message):
        return message
    }
}

_ = handle(.unavailable(message: "opaque"))
_ = try ConnectionMonitor(endpoints: [endpoint])

let english = report.localizedLog(using: .english)
let russian = report.localizedLog(using: .russian)
precondition(report.log == "custom stored log")
precondition(english.contains("NETWORK DIAGNOSIS"))
precondition(russian.contains("СЕТЕВАЯ ДИАГНОСТИКА"))
precondition(english.contains("wifi"))
precondition(russian.contains("Wi-Fi"))
print("consumer-ok")
EOF

(
  cd "$work"
  xcrun swift run --disable-sandbox 2>/dev/null || xcrun swift run
) | tail -n 1 | grep -q "consumer-ok"
echo "consumer resource lookup succeeded"

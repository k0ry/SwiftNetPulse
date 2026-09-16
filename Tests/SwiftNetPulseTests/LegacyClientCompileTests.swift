import XCTest
@testable import SwiftNetPulse

/// Source-compatibility fixture: old exhaustive switches and constructors must compile.
final class LegacyClientCompileTests: XCTestCase {
    func testOldInitializersAndSwitchesCompile() {
        let endpoint = Endpoint(url: URL(string: "https://example.test/")!, rule: .anyData)
        let timings = ProbeTimings(total: 1)
        let result = ProbeResult(
            endpoint: endpoint,
            outcome: .transportFailure("legacy"),
            resolvedIP: nil,
            httpStatus: nil,
            body: Data(),
            timings: timings,
            traceroute: .unavailable(message: "custom opaque")
        )
        XCTAssertNil(result.failureMetadata)

        let failure = ProbeFailure(
            endpoint: endpoint,
            kind: .transport,
            timings: timings,
            message: "legacy"
        )
        XCTAssertNil(failure.metadata)

        XCTAssertEqual(legacyOutcome(result.outcome), "transport")
        XCTAssertEqual(legacyTrace(result.traceroute!), "custom opaque")
        XCTAssertEqual(legacyEvent(.failure(result)), "failure")
        XCTAssertEqual(legacyKind(.ruleMismatch), "rule")
        XCTAssertEqual(legacyError(.emptyEndpointList), "empty")
        XCTAssertNoThrow(try ConnectionMonitor(endpoints: [endpoint]))
    }

    private func legacyOutcome(_ outcome: ProbeOutcome) -> String {
        switch outcome {
        case .success: return "success"
        case .transportFailure: return "transport"
        case .ruleMismatch: return "rule"
        }
    }

    private func legacyTrace(_ result: TracerouteResult) -> String {
        switch result {
        case .hops(let hops): return "hops \(hops.count)"
        case .unavailable(let message): return message
        }
    }

    private func legacyEvent(_ event: ProbeEvent) -> String {
        switch event {
        case .success: return "success"
        case .failure: return "failure"
        }
    }

    private func legacyKind(_ kind: ProbeFailureKind) -> String {
        switch kind {
        case .transport: return "transport"
        case .ruleMismatch: return "rule"
        }
    }

    private func legacyError(_ error: ConnectionMonitorError) -> String {
        switch error {
        case .emptyEndpointList: return "empty"
        case .invalidMonitoringInterval: return "interval"
        }
    }
}

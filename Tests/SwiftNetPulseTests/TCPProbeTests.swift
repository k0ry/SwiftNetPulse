import XCTest
@testable import SwiftNetPulse

final class TCPProbeTests: XCTestCase {
    func testConnectSuccessRecordsDuration() async throws {
        let listener = LocalTCPListener()
        try listener.start()
        defer { listener.stop() }

        let result = await TCPProbe.connect(host: "127.0.0.1", port: listener.port, timeout: 2)
        XCTAssertTrue(result.succeeded)
        XCTAssertGreaterThan(result.duration, 0)
    }

    func testRefusedIsTransportFailureAndDoesNotEvaluateRule() async throws {
        let listener = LocalTCPListener()
        try listener.start()
        let port = listener.port
        listener.stop()
        try await Task.sleep(nanoseconds: 50_000_000)

        let tracer = RecordingTracer()
        let prober = LiveEndpointProber(tracer: tracer)
        let endpoint = sampleEndpoint(
            host: "127.0.0.1",
            port: port,
            rule: .statusEqual(200),
            timeout: 1
        )
        let result = await prober.probe(endpoint, includeTrace: false)
        XCTAssertEqual(result.httpStatus, nil)
        XCTAssertEqual(result.body, Data())
        guard case .transportFailure = result.outcome else {
            return XCTFail("expected transport failure, got \(result.outcome)")
        }
    }

    func testTimeoutIsTransportFailure() async {
        let tracer = RecordingTracer()
        let prober = LiveEndpointProber(tracer: tracer)
        let endpoint = sampleEndpoint(
            host: "192.0.2.1",
            port: 443,
            rule: .anyData,
            timeout: 0.25
        )
        let result = await prober.probe(endpoint, includeTrace: false)
        guard case .transportFailure = result.outcome else {
            return XCTFail("expected transport failure, got \(result.outcome)")
        }
        XCTAssertNil(result.httpStatus)
        XCTAssertGreaterThan(result.timings.total, 0)
        XCTAssertNil(result.timings.transferSpeedBytesPerSecond)
    }

    func testDNSFailureDoesNotEvaluateRule() async {
        let tracer = RecordingTracer()
        let prober = LiveEndpointProber(tracer: tracer)
        let endpoint = sampleEndpoint(
            host: "no-such-host.invalid",
            rule: .statusEqual(200),
            timeout: 2
        )
        let result = await prober.probe(endpoint, includeTrace: false)
        guard case .transportFailure(let reason) = result.outcome else {
            return XCTFail("expected DNS transport failure")
        }
        XCTAssertTrue(reason.contains("DNS"))
        XCTAssertNil(result.httpStatus)
    }
}

import XCTest
@testable import SwiftNetPulse

final class HTTPProbeTests: XCTestCase {
    func testHTTPStatusBodyTimingsAndSpeed() async throws {
        let server = LocalHTTPServer()
        server.statusCode = 200
        server.body = Data(repeating: 0x61, count: 1000)
        try server.start()
        defer { server.stop() }

        let tracer = RecordingTracer()
        let prober = LiveEndpointProber(tracer: tracer)
        let endpoint = Endpoint(
            url: URL(string: "http://127.0.0.1:\(server.port)/payload")!,
            rule: .anyData,
            timeout: 3
        )
        let result = await prober.probe(endpoint, includeTrace: false)
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.httpStatus, 200)
        XCTAssertEqual(result.body.count, 1000)
        XCTAssertNotNil(result.timings.tcpConnect)
        XCTAssertNotNil(result.timings.httpResponse)
        XCTAssertGreaterThan(result.timings.total, 0)
        XCTAssertNotNil(result.timings.transferSpeedBytesPerSecond)
        if let speed = result.timings.transferSpeedBytesPerSecond, let duration = result.timings.httpResponse, duration > 0 {
            XCTAssertEqual(speed, Double(result.body.count) / duration, accuracy: speed * 0.25 + 1)
        }
    }

    func testEmptyBodyOmitsSpeed() async throws {
        let server = LocalHTTPServer()
        server.statusCode = 204
        server.body = Data()
        try server.start()
        defer { server.stop() }

        let prober = LiveEndpointProber(tracer: RecordingTracer())
        let endpoint = Endpoint(
            url: URL(string: "http://127.0.0.1:\(server.port)/empty")!,
            rule: .anyData,
            timeout: 3
        )
        let result = await prober.probe(endpoint, includeTrace: false)
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.httpStatus, 204)
        XCTAssertEqual(result.body, Data())
        XCTAssertNil(result.timings.transferSpeedBytesPerSecond)
    }

    func testRuleMismatchOnUnexpectedStatus() async throws {
        let server = LocalHTTPServer()
        server.statusCode = 500
        server.body = Data("oops".utf8)
        try server.start()
        defer { server.stop() }

        let prober = LiveEndpointProber(tracer: RecordingTracer())
        let endpoint = Endpoint(
            url: URL(string: "http://127.0.0.1:\(server.port)/err")!,
            rule: .statusEqual(200),
            timeout: 3
        )
        let result = await prober.probe(endpoint, includeTrace: false)
        XCTAssertEqual(result.outcome, .ruleMismatch)
        XCTAssertEqual(result.httpStatus, 500)
    }
}

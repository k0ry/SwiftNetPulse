import Combine
import XCTest
@testable import SwiftNetPulse

final class MonitoringTests: XCTestCase {
    func testNonPositiveIntervalThrows() throws {
        let monitor = try makeMonitor(
            endpoints: [sampleEndpoint()],
            prober: ScriptedProber(results: [sampleResult()])
        )
        XCTAssertThrowsError(try monitor.startMonitoring(every: 0)) { error in
            XCTAssertEqual(error as? ConnectionMonitorError, .invalidMonitoringInterval)
        }
        XCTAssertThrowsError(try monitor.startMonitoring(every: -1))
        monitor.stopMonitoring()
        monitor.stopMonitoring()
    }

    func testStopPreventsSecondTick() async throws {
        let prober = ScriptedProber(results: [])
        prober.delay = 0.04
        let monitor = try makeMonitor(endpoints: [sampleEndpoint()], prober: prober)
        try monitor.startMonitoring(every: 0.25)
        try await Task.sleep(nanoseconds: 80_000_000)
        monitor.stopMonitoring()
        let afterStop = prober.callCount
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(prober.callCount, afterStop)
        XCTAssertEqual(afterStop, 1)
    }

    func testFailuresPublisherKinds() async throws {
        let anyData = sampleEndpoint(host: "ok.test", rule: .anyData)
        let needs200 = sampleEndpoint(host: "api.test", rule: .statusEqual(200))
        let down = sampleEndpoint(host: "down.test", rule: .anyData)

        let prober = ScriptedProber(results: [
            sampleResult(endpoint: anyData, outcome: .success, status: 404, body: Data("missing".utf8)),
            sampleResult(endpoint: needs200, outcome: .ruleMismatch, status: 500, body: Data("err".utf8)),
            sampleResult(endpoint: down, outcome: .transportFailure("TCP failed"), status: nil),
        ])
        let tracer = RecordingTracer()
        let monitor = try makeMonitor(
            endpoints: [anyData, needs200, down],
            prober: prober,
            tracer: tracer
        )

        let received = expectation(description: "two failures")
        received.expectedFulfillmentCount = 2
        var failures: [ProbeFailure] = []
        let cancellable = monitor.failures.sink { failure in
            failures.append(failure)
            received.fulfill()
        }
        defer { _ = cancellable }

        try monitor.startMonitoring(every: 10)
        await fulfillment(of: [received], timeout: 3)
        monitor.stopMonitoring()

        XCTAssertEqual(failures.count, 2)
        XCTAssertEqual(failures[0].kind, .ruleMismatch)
        XCTAssertEqual(failures[0].httpStatus, 500)
        XCTAssertEqual(failures[1].kind, .transport)
        XCTAssertNil(failures[1].httpStatus)
        XCTAssertFalse(failures.contains { $0.httpStatus == 404 })
        XCTAssertEqual(tracer.callCount, 0)
        XCTAssertTrue(prober.calls.allSatisfy { $0.includeTrace == false })
    }
}

import Combine
import XCTest
@testable import SwiftNetPulse

final class CheckTests: XCTestCase {
    func testCheckEmitsFirstFailureBeforeReturningBothResults() async throws {
        let server = LocalHTTPServer()
        server.statusCode = 200
        server.body = Data("ok".utf8)
        server.delay = 0.35
        try server.start()
        defer { server.stop() }

        let slow = Endpoint(
            url: URL(string: "http://127.0.0.1:\(server.port)/ok")!,
            rule: .anyData,
            timeout: 3
        )
        let failing = sampleEndpoint(host: "no-such-host.invalid", rule: .anyData, timeout: 1)
        let monitor = try ConnectionMonitor(endpoints: [failing, slow])

        let firstFailure = expectation(description: "failure event before check returns")
        firstFailure.assertForOverFulfill = false
        var events: [ProbeEvent] = []
        let lock = NSLock()
        let cancellable = monitor.events.sink { event in
            lock.lock()
            events.append(event)
            lock.unlock()
            if case .failure = event {
                firstFailure.fulfill()
            }
        }
        defer { _ = cancellable }

        let task = Task { await monitor.check() }
        await fulfillment(of: [firstFailure], timeout: 5)
        lock.lock()
        let countDuring = events.count
        lock.unlock()
        XCTAssertGreaterThanOrEqual(countDuring, 1)

        let report = await task.value
        XCTAssertEqual(report.results.count, 2)
        guard case .transportFailure = report.results[0].outcome else {
            return XCTFail("first result should be transport failure")
        }
        XCTAssertTrue(report.results[1].succeeded)
        XCTAssertTrue(report.log.contains("no-such-host.invalid"))
        XCTAssertTrue(report.log.contains("127.0.0.1"))
    }

    func testCheckTwoEndpointsProducesLogSections() async throws {
        let first = sampleResult(
            endpoint: sampleEndpoint(host: "one.test"),
            outcome: .success,
            status: 200,
            body: Data("ok".utf8)
        )
        let second = sampleResult(
            endpoint: sampleEndpoint(host: "two.test"),
            outcome: .transportFailure("TCP failed"),
            status: nil
        )
        let monitor = try makeMonitor(
            endpoints: [first.endpoint, second.endpoint],
            prober: ScriptedProber(results: [first, second])
        )
        let report = await monitor.check()
        XCTAssertEqual(report.results.count, 2)
        XCTAssertTrue(report.log.contains("one.test"))
        XCTAssertTrue(report.log.contains("two.test"))
        XCTAssertTrue(report.log.contains("transport failure") || report.log.contains("TCP"))
    }
}

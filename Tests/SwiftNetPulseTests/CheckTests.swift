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

    func testDefaultMonitorRendersEnglishRegardlessOfSystemFactory() async throws {
        let result = sampleResult(endpoint: sampleEndpoint(host: "one.test"), outcome: .success, status: 200)
        let monitor = try makeMonitor(
            endpoints: [result.endpoint],
            prober: ScriptedProber(results: [result])
        )
        let report = await monitor.check()
        XCTAssertTrue(report.log.contains("NETWORK DIAGNOSIS"))
        XCTAssertFalse(report.log.contains("СЕТЕВАЯ ДИАГНОСТИКА"))
    }

    func testTwoMonitorsUseIndependentLanguages() async throws {
        let result = sampleResult(
            endpoint: sampleEndpoint(host: "one.test"),
            outcome: .success,
            status: 200,
            body: Data("ok".utf8)
        )
        let english = try makeMonitor(
            endpoints: [result.endpoint],
            prober: ScriptedProber(results: [result]),
            localization: .english
        )
        let russian = try makeMonitor(
            endpoints: [result.endpoint],
            prober: ScriptedProber(results: [result]),
            localization: .russian
        )
        let englishReport = await english.check()
        let russianReport = await russian.check()
        XCTAssertTrue(englishReport.log.contains("NETWORK DIAGNOSIS"))
        XCTAssertTrue(russianReport.log.contains("СЕТЕВАЯ ДИАГНОСТИКА"))
        XCTAssertEqual(englishReport.results[0].outcome, russianReport.results[0].outcome)
        XCTAssertEqual(englishReport.results[0].httpStatus, 200)
    }

    func testRerenderingSavedReportDoesNotCallProber() async throws {
        let prober = ScriptedProber(results: [sampleResult()])
        let monitor = try makeMonitor(endpoints: [sampleEndpoint()], prober: prober)
        let report = await monitor.check()
        XCTAssertEqual(prober.callCount, 1)
        let stored = report.log
        let againEnglish = report.localizedLog(using: .english)
        let russian = report.localizedLog(using: .russian)
        XCTAssertEqual(prober.callCount, 1)
        XCTAssertEqual(report.log, stored)
        XCTAssertTrue(againEnglish.contains("NETWORK DIAGNOSIS"))
        XCTAssertTrue(russian.contains("СЕТЕВАЯ ДИАГНОСТИКА"))
        XCTAssertEqual(report.results.count, 1)
    }

    func testCustomStoredLogIsNotTranslated() {
        let report = DiagnosisReport(
            date: Date(timeIntervalSince1970: 1_789_560_000),
            snapshot: NetworkSnapshot(pathType: "wifi"),
            results: [sampleResult()],
            log: "hand-written log"
        )
        XCTAssertEqual(report.log, "hand-written log")
        XCTAssertTrue(report.localizedLog(using: .russian).contains("СЕТЕВАЯ ДИАГНОСТИКА"))
        XCTAssertFalse(report.localizedLog(using: .russian).contains("hand-written log"))
    }

    func testCheckCarriesTracerouteMetadata() async throws {
        let tracer = RecordingTracer(result: .unavailable(message: "ICMP socket could not be opened"))
        tracer.details.unavailableMetadata = ProbeFailureMetadata(stage: .traceroute, reasonCode: ProbeReason.socket)
        let endpoint = sampleEndpoint(host: "traced.test", traceOnCheck: true)
        let inner = ScriptedProber(results: [sampleResult(endpoint: endpoint)])
        let prober = LiveTraceAttachingProber(inner: inner, tracer: tracer)
        let monitor = try makeMonitor(endpoints: [endpoint], prober: prober, tracer: tracer, localization: .russian)
        let report = await monitor.check()
        XCTAssertEqual(report.results[0].tracerouteFailureMetadata?.reasonCode, ProbeReason.socket)
        XCTAssertTrue(report.log.contains("Трассировка недоступна"))
        XCTAssertTrue(report.log.contains("не удалось открыть ICMP-сокет"))
    }
}

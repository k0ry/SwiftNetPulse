import XCTest
@testable import SwiftNetPulse

final class TracerouteTests: XCTestCase {
    func testHopFormatting() {
        let hop = TraceHop(index: 10, address: "51.250.89.190", rtt: 0.0243)
        XCTAssertEqual(LogFormatter.format(hop: hop), "10: 51.250.89.190 24.30 ms |")
        let timedOut = TraceHop(index: 7)
        XCTAssertEqual(LogFormatter.format(hop: timedOut), "7: * * |")
    }

    func testMaxHopsExceededReturnsPartialResult() {
        let result = PathTraceCollector.collect(maxHops: 3) { _ in .timeout }
        guard case .hops(let hops) = result else {
            return XCTFail("expected hops")
        }
        XCTAssertEqual(hops.count, 3)
        XCTAssertEqual(hops.map(\.index), [1, 2, 3])
        XCTAssertTrue(hops.allSatisfy { $0.address == nil && $0.rtt == nil })
        XCTAssertTrue(result.log.contains("1: * * |"))
    }

    func testTimeoutHopPreservedInList() {
        let result = PathTraceCollector.collect(maxHops: 8) { ttl in
            if ttl == 7 { return .timeout }
            if ttl == 8 { return .hop(address: "9.9.9.9", rtt: 0.02, destination: true) }
            return .hop(address: "10.0.0.\(ttl)", rtt: 0.001, destination: false)
        }
        let hops = result.hopList
        XCTAssertEqual(hops[6].index, 7)
        XCTAssertNil(hops[6].address)
        XCTAssertNil(hops[6].rtt)
        XCTAssertEqual(hops[7].address, "9.9.9.9")
        XCTAssertTrue(result.log.contains("7: * * |"))
    }

    func testEnglishAndRussianHopLabelsAndPrecision() {
        let hops: TracerouteResult = .hops([
            TraceHop(index: 10, address: "51.250.89.190", rtt: 0.0243),
            TraceHop(index: 7),
        ])
        let english = hops.localizedLog(using: .english)
        let russian = hops.localizedLog(using: .russian)
        XCTAssertTrue(english.contains("Trace start"))
        XCTAssertTrue(english.contains("10: 51.250.89.190 24.30 ms |"))
        XCTAssertTrue(english.contains("7: * * |"))
        XCTAssertTrue(russian.contains("Начало трассировки"))
        XCTAssertTrue(russian.contains("10: 51.250.89.190 24,30 мс |"))
        XCTAssertTrue(russian.contains("7: * * |"))
        XCTAssertEqual(TracerouteResult.hops([]).localizedLog(using: .english), "Trace start")
    }

    func testTypedUnavailableReasonsLocalize() {
        let socket = TracerouteDetails(
            result: .unavailable(message: "ICMP socket could not be opened"),
            unavailableMetadata: ProbeFailureMetadata(stage: .traceroute, reasonCode: ProbeReason.socket)
        )
        let dns = TracerouteDetails(
            result: .unavailable(message: "cannot resolve example.test for traceroute"),
            unavailableMetadata: ProbeFailureMetadata(
                stage: .traceroute,
                reasonCode: ProbeReason.tracerouteDNS,
                arguments: ["example.test"]
            )
        )
        let ipv4 = TracerouteDetails(
            result: .unavailable(message: "traceroute supports IPv4 only"),
            unavailableMetadata: ProbeFailureMetadata(stage: .traceroute, reasonCode: ProbeReason.ipv4Only)
        )
        XCTAssertEqual(socket.localizedLog(using: .english), "Traceroute unavailable: ICMP socket could not be opened")
        XCTAssertEqual(socket.localizedLog(using: .russian), "Трассировка недоступна: не удалось открыть ICMP-сокет")
        XCTAssertTrue(dns.localizedLog(using: .russian).contains("example.test"))
        XCTAssertTrue(ipv4.localizedLog(using: .russian).contains("IPv4"))
        XCTAssertEqual(socket.log, "Traceroute unavailable: ICMP socket could not be opened")
    }

    func testLegacyUnavailableStringIsRetainedExactly() {
        let result = TracerouteResult.unavailable(message: "custom kernel message 0xdead")
        XCTAssertEqual(
            result.localizedLog(using: .russian),
            "Трассировка недоступна: custom kernel message 0xdead"
        )
        XCTAssertEqual(result.log, "Traceroute unavailable: custom kernel message 0xdead")
    }

    func testUnavailableWhenSocketCannotOpen() async {
        let tracer = ICMPPathTracer(socketFactory: { -1 })
        let monitor = try? ConnectionMonitor(
            endpoints: [sampleEndpoint()],
            prober: ScriptedProber(results: [sampleResult()]),
            tracer: tracer,
            snapshotProvider: FixedSnapshot()
        )
        let result = await monitor?.traceroute(to: "example.com", maxHops: 3)
        guard case .unavailable(let message) = result else {
            return XCTFail("expected unavailable, got \(String(describing: result))")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(result?.hopList, [])
        XCTAssertTrue(result?.log.contains("unavailable") ?? false)
    }

    func testTraceOnCheckOnlyDuringCheck() async throws {
        let endpointOn = sampleEndpoint(host: "traced.test", traceOnCheck: true)
        let endpointOff = sampleEndpoint(host: "plain.test", traceOnCheck: false)
        let tracer = RecordingTracer(result: .hops([TraceHop(index: 1, address: "1.1.1.1", rtt: 0.01)]))
        let successOn = sampleResult(endpoint: endpointOn, traceroute: tracer.result)
        let successOff = sampleResult(endpoint: endpointOff, traceroute: nil)

        let checkProber = ScriptedProber(results: [successOn, successOff])
        checkProber.onProbe = { endpoint, includeTrace in
            if includeTrace {
                // Mimic LiveEndpointProber attaching traceroute
            }
        }

        let live = LiveTraceAttachingProber(inner: checkProber, tracer: tracer)
        let monitor = try makeMonitor(
            endpoints: [endpointOn, endpointOff],
            prober: live,
            tracer: tracer
        )

        let report = await monitor.check()
        XCTAssertEqual(tracer.hosts, ["traced.test"])
        XCTAssertNotNil(report.results[0].traceroute)
        XCTAssertNil(report.results[1].traceroute)
        XCTAssertTrue(report.log.contains("1.1.1.1"))

        tracer.resetHosts()
        let monitorProber = ScriptedProber(results: [successOn, successOff])
        let monitor2 = try makeMonitor(
            endpoints: [endpointOn, endpointOff],
            prober: monitorProber,
            tracer: tracer
        )
        let tick = expectation(description: "monitor tick")
        monitorProber.onProbe = { _, includeTrace in
            XCTAssertFalse(includeTrace)
            tick.fulfill()
        }
        tick.expectedFulfillmentCount = 2
        try monitor2.startMonitoring(every: 10)
        await fulfillment(of: [tick], timeout: 2)
        monitor2.stopMonitoring()
        XCTAssertEqual(tracer.callCount, 0)
        XCTAssertTrue(monitorProber.calls.allSatisfy { !$0.includeTrace })
    }
}

/// Applies traceroute the same way ConnectionMonitor asks the live prober to.
final class LiveTraceAttachingProber: EndpointProbing {
    let inner: ScriptedProber
    let tracer: RecordingTracer

    init(inner: ScriptedProber, tracer: RecordingTracer) {
        self.inner = inner
        self.tracer = tracer
    }

    func probe(_ endpoint: Endpoint, includeTrace: Bool) async -> ProbeResult {
        var result = await inner.probe(endpoint, includeTrace: includeTrace)
        if includeTrace, let host = endpoint.url.host {
            let details = await tracer.trace(host: host, maxHops: 30)
            result.traceroute = details.result
            result.tracerouteFailureMetadata = details.unavailableMetadata
        }
        return result
    }
}

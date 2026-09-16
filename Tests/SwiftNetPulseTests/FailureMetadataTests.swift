import XCTest
@testable import SwiftNetPulse

final class FailureMetadataTests: XCTestCase {
    func testTypedStageControlsLabelsDespiteOpaqueText() {
        let opaque = "DNS timeout TCP words"
        let dns = ProbeResult(
            endpoint: sampleEndpoint(),
            outcome: .transportFailure(opaque),
            timings: ProbeTimings(dns: 0.01, total: 0.01),
            failureMetadata: ProbeFailureMetadata(stage: .dns, reasonCode: ProbeReason.dnsFailed, arguments: ["x.test"])
        )
        let tcp = ProbeResult(
            endpoint: sampleEndpoint(),
            outcome: .transportFailure(opaque),
            timings: ProbeTimings(tcpConnect: 0.02, total: 0.02),
            failureMetadata: ProbeFailureMetadata(
                stage: .tcp,
                reasonCode: ProbeReason.tcpFailed,
                arguments: ["10.0.0.1", "443"]
            )
        )
        let http = ProbeResult(
            endpoint: sampleEndpoint(),
            outcome: .transportFailure(opaque),
            httpStatus: nil,
            timings: ProbeTimings(total: 0.03),
            failureMetadata: ProbeFailureMetadata(stage: .http, reasonCode: ProbeReason.urlTimeout)
        )
        let dnsLog = LogFormatter.report(date: Date(), snapshot: NetworkSnapshot(), results: [dns])
        let tcpLog = LogFormatter.report(date: Date(), snapshot: NetworkSnapshot(), results: [tcp])
        let httpLog = LogFormatter.report(date: Date(), snapshot: NetworkSnapshot(), results: [http])
        XCTAssertTrue(dnsLog.contains("DNS: failed"))
        XCTAssertTrue(dnsLog.contains("DNS failed for x.test"))
        XCTAssertTrue(tcpLog.contains("TCP: failed in"))
        XCTAssertTrue(tcpLog.contains("TCP 10.0.0.1:443 failed"))
        XCTAssertTrue(httpLog.contains("request timed out"))
        XCTAssertFalse(httpLog.contains("DNS: failed"))
    }

    func testLegacyFailureDoesNotInferStageFromWords() {
        let legacy = ProbeResult(
            endpoint: sampleEndpoint(),
            outcome: .transportFailure("looks like DNS and TCP failed"),
            timings: ProbeTimings(tcpConnect: 0.05, total: 0.05)
        )
        let log = LogFormatter.report(date: Date(), snapshot: NetworkSnapshot(), results: [legacy])
        XCTAssertTrue(log.contains("looks like DNS and TCP failed"))
        XCTAssertFalse(log.contains("DNS: failed"))
        XCTAssertTrue(log.contains("TCP: connected in"))
        XCTAssertNil(legacy.failureMetadata)
        let failure = ProbeFailure(result: legacy)
        XCTAssertEqual(failure.message, "looks like DNS and TCP failed")
        XCTAssertNil(failure.metadata)
    }

    func testMetadataIncludedInEquality() {
        let timings = ProbeTimings(total: 0.1)
        let without = ProbeResult(endpoint: sampleEndpoint(), outcome: .transportFailure("x"), timings: timings)
        let with = ProbeResult(
            endpoint: sampleEndpoint(),
            outcome: .transportFailure("x"),
            timings: timings,
            failureMetadata: ProbeFailureMetadata(stage: .dns, reasonCode: ProbeReason.dnsFailed, arguments: ["h"])
        )
        XCTAssertNotEqual(without, with)
        XCTAssertEqual(with, with)
    }

    func testKnownAndUnknownURLErrors() {
        let timeout = URLError(.timedOut)
        let mappedTimeout = TransportErrorMapper.map(timeout)
        XCTAssertEqual(mappedTimeout.metadata.reasonCode, ProbeReason.urlTimeout)
        XCTAssertEqual(mappedTimeout.metadata.stage, .http)
        XCTAssertEqual(mappedTimeout.message, "request timed out")
        XCTAssertEqual(mappedTimeout.metadata.systemDomain, NSURLErrorDomain)
        XCTAssertEqual(mappedTimeout.metadata.rawDetail, timeout.localizedDescription)

        let dns = URLError(.cannotFindHost)
        XCTAssertEqual(TransportErrorMapper.map(dns).metadata.stage, .dns)

        let tls = URLError(.secureConnectionFailed)
        XCTAssertEqual(TransportErrorMapper.map(tls).metadata.reasonCode, ProbeReason.urlTLS)
        XCTAssertEqual(TransportErrorMapper.map(tls).metadata.stage, .tls)

        let unknown = NSError(domain: "CustomDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Fehler"])
        let mappedUnknown = TransportErrorMapper.map(unknown)
        XCTAssertEqual(mappedUnknown.metadata.reasonCode, ProbeReason.urlGeneric)
        XCTAssertEqual(mappedUnknown.metadata.arguments, ["CustomDomain", "42"])
        XCTAssertEqual(mappedUnknown.metadata.rawDetail, "Fehler")
        XCTAssertTrue(mappedUnknown.message.contains("CustomDomain"))
        XCTAssertTrue(mappedUnknown.message.contains("42"))
    }

    func testRawOSDetailKeptSeparateAndLabelled() {
        let metadata = ProbeFailureMetadata(
            stage: .http,
            reasonCode: ProbeReason.urlTimeout,
            systemDomain: NSURLErrorDomain,
            systemCode: URLError.timedOut.rawValue,
            rawDetail: "Die Anfrage hat das Zeitlimit überschritten."
        )
        let result = ProbeResult(
            endpoint: sampleEndpoint(),
            outcome: .transportFailure("request timed out"),
            timings: ProbeTimings(total: 1),
            failureMetadata: metadata
        )
        let en = LogFormatter.report(date: Date(), snapshot: NetworkSnapshot(), results: [result], localization: .english)
        let ru = LogFormatter.report(date: Date(), snapshot: NetworkSnapshot(), results: [result], localization: .russian)
        XCTAssertTrue(en.contains("Outcome: transport failure (request timed out)"))
        XCTAssertTrue(en.contains("System detail (raw): Die Anfrage hat das Zeitlimit überschritten."))
        XCTAssertTrue(ru.contains("истекло время ожидания запроса"))
        XCTAssertTrue(ru.contains("Системные сведения (без перевода): Die Anfrage hat das Zeitlimit überschritten."))
    }

    func testProbeFailureCopiesMetadataFromResult() {
        let result = ProbeResult(
            endpoint: sampleEndpoint(),
            outcome: .transportFailure("DNS failed for h"),
            timings: ProbeTimings(total: 0.2),
            failureMetadata: ProbeFailureMetadata(stage: .dns, reasonCode: ProbeReason.dnsFailed, arguments: ["h"])
        )
        let failure = ProbeFailure(result: result)
        XCTAssertEqual(failure.kind, .transport)
        XCTAssertEqual(failure.metadata?.stage, .dns)
        XCTAssertEqual(failure.metadata?.reasonCode, ProbeReason.dnsFailed)
    }

    func testLiveDNSFailurePublishesTypedMetadata() async {
        let prober = LiveEndpointProber(tracer: RecordingTracer())
        let endpoint = sampleEndpoint(host: "no-such-host.invalid", rule: .statusEqual(200), timeout: 2)
        let result = await prober.probe(endpoint, includeTrace: false)
        guard case .transportFailure(let reason) = result.outcome else {
            return XCTFail("expected DNS transport failure")
        }
        XCTAssertTrue(reason.contains("DNS"))
        XCTAssertEqual(result.failureMetadata?.stage, .dns)
        XCTAssertEqual(result.failureMetadata?.reasonCode, ProbeReason.dnsFailed)
        XCTAssertEqual(result.failureMetadata?.arguments, ["no-such-host.invalid"])
    }
}

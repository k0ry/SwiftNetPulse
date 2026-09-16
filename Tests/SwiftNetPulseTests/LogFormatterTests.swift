import XCTest
@testable import SwiftNetPulse

final class LogFormatterTests: XCTestCase {
    private let fixtureDate = Date(timeIntervalSince1970: 1_789_560_000)

    func testLogContainsRequiredFieldsWithoutAndroidWording() {
        let log = LogFormatter.report(
            date: Date(),
            snapshot: successSnapshot,
            results: [successResult],
            localization: .english
        )

        XCTAssertTrue(log.contains("skills.example.com"))
        XCTAssertTrue(log.contains("51.250.89.190"))
        XCTAssertTrue(log.contains("192.168.31.57"))
        XCTAssertTrue(log.contains("DNS"))
        XCTAssertTrue(log.contains("TCP"))
        XCTAssertTrue(log.contains("HTTPS connect"))
        XCTAssertTrue(log.contains("HTTP status: 404"))
        XCTAssertTrue(log.contains("HTTP response"))
        XCTAssertTrue(log.contains("Total"))
        XCTAssertTrue(log.contains("Speed"))
        XCTAssertTrue(log.contains("Root request prohibited"))
        XCTAssertTrue(log.contains("192.168.0.1"))
        XCTAssertFalse(log.contains("skills.a"))
        XCTAssertFalse(log.contains("Manufacturer"))
    }

    func testEnglishSuccessFixtureMatchesBaseline() {
        let log = LogFormatter.report(
            date: fixtureDate,
            snapshot: successSnapshot,
            results: [successResult],
            localization: .english
        )
        XCTAssertEqual(log, loadFixture("english-report-success.txt"))
    }

    func testRussianSuccessFixture() {
        let log = LogFormatter.report(
            date: fixtureDate,
            snapshot: successSnapshot,
            results: [successResult],
            localization: .russian
        )
        XCTAssertEqual(log, loadFixture("russian-report-success.txt"))
        XCTAssertTrue(log.contains("Root request prohibited"))
        XCTAssertTrue(log.contains("2026-09-16T12:00:00.000Z"))
    }

    func testNumericLocaleIndependentOfLanguage() {
        let mixed = ReportLocalization(languageIdentifier: "en", localeIdentifier: "ru_RU")
        let log = LogFormatter.report(
            date: fixtureDate,
            snapshot: successSnapshot,
            results: [successResult],
            localization: mixed
        )
        XCTAssertTrue(log.contains("NETWORK DIAGNOSIS"))
        XCTAssertTrue(log.contains("6,0 ms"))
        XCTAssertTrue(log.contains("1,00 ms"))
        XCTAssertFalse(log.contains("СЕТЕВАЯ ДИАГНОСТИКА"))
    }

    func testUnknownPathTypePreservedAndNilVPNOmitted() {
        let snapshot = NetworkSnapshot(
            pathType: "carrier-pigeon",
            localIPv4: nil,
            dnsServers: [],
            vpnDetected: nil
        )
        let result = ProbeResult(
            endpoint: sampleEndpoint(),
            outcome: .success,
            timings: ProbeTimings(total: 0.01)
        )
        let log = LogFormatter.report(date: fixtureDate, snapshot: snapshot, results: [result])
        XCTAssertTrue(log.contains("Network type: carrier-pigeon"))
        XCTAssertFalse(log.contains("VPN detected"))
        XCTAssertFalse(log.contains("Local IP"))
        XCTAssertFalse(log.contains("DNS servers"))
    }

    func testEmptyAndBinaryBodyPreview() {
        let empty = ProbeResult(
            endpoint: sampleEndpoint(host: "empty.test"),
            outcome: .success,
            httpStatus: 204,
            body: Data(),
            timings: ProbeTimings(total: 0.01)
        )
        let binary = ProbeResult(
            endpoint: sampleEndpoint(host: "bin.test"),
            outcome: .success,
            httpStatus: 200,
            body: Data([0xFF, 0xFE, 0x00]),
            timings: ProbeTimings(total: 0.01)
        )
        let emptyLog = LogFormatter.report(date: fixtureDate, snapshot: NetworkSnapshot(), results: [empty])
        let binaryLog = LogFormatter.report(date: fixtureDate, snapshot: NetworkSnapshot(), results: [binary])
        XCTAssertFalse(emptyLog.contains("Body preview"))
        XCTAssertTrue(binaryLog.contains("Body preview"))
        XCTAssertTrue(binaryLog.contains("<binary>"))
        let russianBinary = LogFormatter.report(
            date: fixtureDate,
            snapshot: NetworkSnapshot(),
            results: [binary],
            localization: .russian
        )
        XCTAssertTrue(russianBinary.contains("<двоичные данные>"))
    }

    func testUnicodeBodyPreviewIsLiteral() {
        let result = ProbeResult(
            endpoint: sampleEndpoint(),
            outcome: .success,
            httpStatus: 200,
            body: Data("Привет café".utf8),
            timings: ProbeTimings(total: 0.01)
        )
        let log = LogFormatter.report(date: fixtureDate, snapshot: NetworkSnapshot(), results: [result])
        XCTAssertTrue(log.contains("Привет café"))
    }

    func testVPNYesNoAndKnownPathLabels() {
        let yes = NetworkSnapshot(pathType: "cellular", vpnDetected: true)
        let no = NetworkSnapshot(pathType: "ethernet", vpnDetected: false)
        let yesLog = LogFormatter.report(date: fixtureDate, snapshot: yes, results: [], localization: .english)
        let ruLog = LogFormatter.report(date: fixtureDate, snapshot: yes, results: [], localization: .russian)
        XCTAssertTrue(yesLog.contains("VPN detected: YES"))
        XCTAssertTrue(yesLog.contains("Network type: cellular"))
        XCTAssertTrue(ruLog.contains("VPN обнаружен: ДА"))
        XCTAssertTrue(ruLog.contains("сотовая"))
        let ethernet = LogFormatter.report(date: fixtureDate, snapshot: no, results: [])
        XCTAssertTrue(ethernet.contains("VPN detected: NO"))
        XCTAssertTrue(ethernet.contains("ethernet"))
    }

    func testRuleMismatchOutcomeUnchanged() {
        let result = ProbeResult(
            endpoint: sampleEndpoint(rule: .statusEqual(200)),
            outcome: .ruleMismatch,
            httpStatus: 404,
            body: Data("missing".utf8),
            timings: ProbeTimings(total: 0.02)
        )
        let log = LogFormatter.report(date: fixtureDate, snapshot: NetworkSnapshot(), results: [result])
        XCTAssertTrue(log.contains("Outcome: rule mismatch"))
        XCTAssertTrue(log.contains("HTTP status: 404"))
        XCTAssertTrue(log.contains("missing"))
    }

    private var successSnapshot: NetworkSnapshot {
        NetworkSnapshot(
            pathType: "wifi",
            localIPv4: "192.168.31.57",
            dnsServers: ["192.168.31.1"],
            vpnDetected: false
        )
    }

    private var successResult: ProbeResult {
        ProbeResult(
            endpoint: Endpoint(
                url: URL(string: "https://skills.example.com/root")!,
                rule: .anyData
            ),
            outcome: .success,
            resolvedIP: "51.250.89.190",
            httpStatus: 404,
            body: Data(#"{"error":404,"error_text":"Root request prohibited"}"#.utf8),
            timings: ProbeTimings(
                dns: 0.006,
                tcpConnect: 0.015,
                httpsConnect: 0.033,
                tls: 0.01,
                httpResponse: 0.03,
                total: 0.063,
                transferSpeedBytesPerSecond: 1800
            ),
            traceroute: .hops([
                TraceHop(index: 1, address: "192.168.0.1", rtt: 0.001),
                TraceHop(index: 2),
            ])
        )
    }
}

func loadFixture(_ name: String) -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
    let text = try! String(contentsOf: url, encoding: .utf8)
    return text.trimmingCharacters(in: .newlines)
}

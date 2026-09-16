import XCTest
@testable import SwiftNetPulse

final class LogFormatterTests: XCTestCase {
    func testLogContainsRequiredFieldsWithoutAndroidWording() {
        let endpoint = Endpoint(
            url: URL(string: "https://skills.example.com/root")!,
            rule: .anyData
        )
        let result = ProbeResult(
            endpoint: endpoint,
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
        let snapshot = NetworkSnapshot(
            pathType: "wifi",
            localIPv4: "192.168.31.57",
            dnsServers: ["192.168.31.1"],
            vpnDetected: false
        )
        let log = LogFormatter.report(date: Date(), snapshot: snapshot, results: [result])

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
}

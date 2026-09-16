import XCTest
@testable import SwiftNetPulse

final class ProbeRuleTests: XCTestCase {
    func testAnyDataSucceedsOn404() {
        let body = Data(#"{"error":404}"#.utf8)
        XCTAssertTrue(ProbeRule.anyData.evaluate(status: 404, body: body))
    }

    func testAnyDataSucceedsOnEmptyBody() {
        XCTAssertTrue(ProbeRule.anyData.evaluate(status: 204, body: Data()))
    }

    func testStatusEqualAndNotEqual() {
        XCTAssertTrue(ProbeRule.statusEqual(403).evaluate(status: 403, body: Data()))
        XCTAssertFalse(ProbeRule.statusEqual(200).evaluate(status: 404, body: Data()))
        XCTAssertTrue(ProbeRule.statusNotEqual(404).evaluate(status: 200, body: Data()))
        XCTAssertFalse(ProbeRule.statusNotEqual(404).evaluate(status: 404, body: Data()))
    }

    func testStatusInAndClass() {
        XCTAssertTrue(ProbeRule.statusIn([401, 403]).evaluate(status: 401, body: Data()))
        XCTAssertFalse(ProbeRule.statusIn([401, 403]).evaluate(status: 200, body: Data()))
        XCTAssertTrue(ProbeRule.statusClass(.success).evaluate(status: 204, body: Data()))
        XCTAssertFalse(ProbeRule.statusClass(.success).evaluate(status: 404, body: Data()))
        XCTAssertTrue(ProbeRule.statusClass(.clientError).evaluate(status: 404, body: Data()))
        XCTAssertTrue(ProbeRule.statusClass(.serverError).evaluate(status: 500, body: Data()))
        XCTAssertTrue(ProbeRule.statusClass(.redirect).evaluate(status: 301, body: Data()))
    }

    func testBodyEqualAndContains() {
        XCTAssertTrue(ProbeRule.bodyEqual("ok").evaluate(status: 200, body: Data("ok".utf8)))
        XCTAssertFalse(ProbeRule.bodyEqual("ok").evaluate(status: 200, body: Data("ok\n".utf8)))
        let json = Data(#"{"error_text":"Root request prohibited"}"#.utf8)
        XCTAssertTrue(ProbeRule.bodyContains("Root request prohibited").evaluate(status: 404, body: json))
    }

    func testNonUTF8BodyFailsStringRules() {
        let bytes = Data([0xFF, 0xFE, 0x00])
        XCTAssertFalse(ProbeRule.bodyEqual("ok").evaluate(status: 200, body: bytes))
        XCTAssertFalse(ProbeRule.bodyContains("ok").evaluate(status: 200, body: bytes))
    }

    func testNestedAll() {
        let rule = ProbeRule.all([.statusEqual(200), .bodyContains("ok")])
        XCTAssertTrue(rule.evaluate(status: 200, body: Data("ok".utf8)))
        XCTAssertFalse(rule.evaluate(status: 200, body: Data("error".utf8)))
        XCTAssertFalse(rule.evaluate(status: 500, body: Data("ok".utf8)))
        let nested = ProbeRule.all([.all([.statusClass(.success)]), .bodyEqual("pong")])
        XCTAssertTrue(nested.evaluate(status: 201, body: Data("pong".utf8)))
    }

    func testTransferSpeedOmittedWhenMissingBodyOrZeroDuration() {
        XCTAssertNil(ProbeTimings.transferSpeed(bytes: 0, responseDuration: 0.05))
        XCTAssertNil(ProbeTimings.transferSpeed(bytes: 1000, responseDuration: 0))
        XCTAssertNil(ProbeTimings.transferSpeed(bytes: 1000, responseDuration: nil))
        let speed = ProbeTimings.transferSpeed(bytes: 1000, responseDuration: 0.05)
        XCTAssertEqual(speed ?? -1, 20_000, accuracy: 0.1)
    }
}

import XCTest
@testable import SwiftNetPulse

final class InitTests: XCTestCase {
    func testInitRejectsEmptyEndpointList() {
        XCTAssertThrowsError(try ConnectionMonitor(endpoints: [])) { error in
            XCTAssertEqual(error as? ConnectionMonitorError, .emptyEndpointList)
        }
    }

    func testInitAcceptsSingleEndpoint() throws {
        let monitor = try ConnectionMonitor(endpoints: [sampleEndpoint()])
        XCTAssertNotNil(monitor)
    }
}

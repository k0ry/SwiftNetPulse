import Foundation

extension ProbeRule {
    public func evaluate(status: Int, body: Data) -> Bool {
        switch self {
        case .anyData:
            return true
        case .statusEqual(let code):
            return status == code
        case .statusNotEqual(let code):
            return status != code
        case .statusIn(let codes):
            return codes.contains(status)
        case .statusClass(let statusClass):
            return statusClass.matches(status)
        case .bodyEqual(let expected):
            guard let text = String(data: body, encoding: .utf8) else { return false }
            return text == expected
        case .bodyContains(let snippet):
            guard let text = String(data: body, encoding: .utf8) else { return false }
            return text.contains(snippet)
        case .all(let rules):
            return rules.allSatisfy { $0.evaluate(status: status, body: body) }
        }
    }
}

import Foundation

public struct Endpoint: Equatable, Sendable {
    public var url: URL
    public var rule: ProbeRule
    public var timeout: TimeInterval
    public var traceOnCheck: Bool

    public init(
        url: URL,
        rule: ProbeRule,
        timeout: TimeInterval = 10,
        traceOnCheck: Bool = false
    ) {
        self.url = url
        self.rule = rule
        self.timeout = timeout
        self.traceOnCheck = traceOnCheck
    }

    public var port: UInt16 {
        if let port = url.port, port > 0, port <= Int(UInt16.max) {
            return UInt16(port)
        }
        if url.scheme?.lowercased() == "http" {
            return 80
        }
        return 443
    }
}

public enum HTTPStatusClass: Equatable, Sendable {
    case success
    case redirect
    case clientError
    case serverError

    public func matches(_ status: Int) -> Bool {
        switch self {
        case .success: return (200 ... 299).contains(status)
        case .redirect: return (300 ... 399).contains(status)
        case .clientError: return (400 ... 499).contains(status)
        case .serverError: return (500 ... 599).contains(status)
        }
    }
}

public enum ProbeRule: Equatable, Sendable {
    case anyData
    case statusEqual(Int)
    case statusNotEqual(Int)
    case statusIn(Set<Int>)
    case statusClass(HTTPStatusClass)
    case bodyEqual(String)
    case bodyContains(String)
    case all([ProbeRule])
}

public struct ProbeTimings: Equatable, Sendable {
    public var dns: TimeInterval?
    public var tcpConnect: TimeInterval?
    public var httpsConnect: TimeInterval?
    public var tls: TimeInterval?
    public var httpResponse: TimeInterval?
    public var total: TimeInterval
    public var transferSpeedBytesPerSecond: Double?

    public init(
        dns: TimeInterval? = nil,
        tcpConnect: TimeInterval? = nil,
        httpsConnect: TimeInterval? = nil,
        tls: TimeInterval? = nil,
        httpResponse: TimeInterval? = nil,
        total: TimeInterval,
        transferSpeedBytesPerSecond: Double? = nil
    ) {
        self.dns = dns
        self.tcpConnect = tcpConnect
        self.httpsConnect = httpsConnect
        self.tls = tls
        self.httpResponse = httpResponse
        self.total = total
        self.transferSpeedBytesPerSecond = transferSpeedBytesPerSecond
    }

    public static func transferSpeed(bytes: Int, responseDuration: TimeInterval?) -> Double? {
        guard bytes > 0, let duration = responseDuration, duration > 0 else {
            return nil
        }
        return Double(bytes) / duration
    }
}

public enum ProbeOutcome: Equatable, Sendable {
    case success
    case transportFailure(String)
    case ruleMismatch
}

public struct ProbeResult: Equatable, Sendable {
    public var endpoint: Endpoint
    public var outcome: ProbeOutcome
    public var resolvedIP: String?
    public var httpStatus: Int?
    public var body: Data
    public var timings: ProbeTimings
    public var traceroute: TracerouteResult?

    public init(
        endpoint: Endpoint,
        outcome: ProbeOutcome,
        resolvedIP: String? = nil,
        httpStatus: Int? = nil,
        body: Data = Data(),
        timings: ProbeTimings,
        traceroute: TracerouteResult? = nil
    ) {
        self.endpoint = endpoint
        self.outcome = outcome
        self.resolvedIP = resolvedIP
        self.httpStatus = httpStatus
        self.body = body
        self.timings = timings
        self.traceroute = traceroute
    }

    public var succeeded: Bool {
        if case .success = outcome { return true }
        return false
    }
}

public enum ProbeEvent: Equatable, Sendable {
    case success(ProbeResult)
    case failure(ProbeResult)
}

public enum ProbeFailureKind: Equatable, Sendable {
    case transport
    case ruleMismatch
}

public struct ProbeFailure: Equatable, Sendable {
    public var endpoint: Endpoint
    public var kind: ProbeFailureKind
    public var httpStatus: Int?
    public var body: Data
    public var timings: ProbeTimings
    public var message: String?

    public init(
        endpoint: Endpoint,
        kind: ProbeFailureKind,
        httpStatus: Int? = nil,
        body: Data = Data(),
        timings: ProbeTimings,
        message: String? = nil
    ) {
        self.endpoint = endpoint
        self.kind = kind
        self.httpStatus = httpStatus
        self.body = body
        self.timings = timings
        self.message = message
    }

    public init(result: ProbeResult) {
        endpoint = result.endpoint
        httpStatus = result.httpStatus
        body = result.body
        timings = result.timings
        switch result.outcome {
        case .success:
            kind = .transport
            message = nil
        case .transportFailure(let reason):
            kind = .transport
            message = reason
        case .ruleMismatch:
            kind = .ruleMismatch
            message = nil
        }
    }
}

public struct NetworkSnapshot: Equatable, Sendable {
    public var pathType: String?
    public var localIPv4: String?
    public var dnsServers: [String]
    public var vpnDetected: Bool?

    public init(
        pathType: String? = nil,
        localIPv4: String? = nil,
        dnsServers: [String] = [],
        vpnDetected: Bool? = nil
    ) {
        self.pathType = pathType
        self.localIPv4 = localIPv4
        self.dnsServers = dnsServers
        self.vpnDetected = vpnDetected
    }
}

public struct DiagnosisReport: Equatable, Sendable {
    public var date: Date
    public var snapshot: NetworkSnapshot
    public var results: [ProbeResult]
    public var log: String

    public init(date: Date = Date(), snapshot: NetworkSnapshot, results: [ProbeResult], log: String) {
        self.date = date
        self.snapshot = snapshot
        self.results = results
        self.log = log
    }
}

public struct TraceHop: Equatable, Sendable {
    public var index: Int
    public var address: String?
    public var hostname: String?
    public var rtt: TimeInterval?

    public init(index: Int, address: String? = nil, hostname: String? = nil, rtt: TimeInterval? = nil) {
        self.index = index
        self.address = address
        self.hostname = hostname
        self.rtt = rtt
    }
}

public enum TracerouteResult: Equatable, Sendable {
    case hops([TraceHop])
    case unavailable(message: String)

    public var hopList: [TraceHop] {
        switch self {
        case .hops(let hops): return hops
        case .unavailable: return []
        }
    }

    public var log: String {
        LogFormatter.tracerouteLog(self)
    }
}

public enum ConnectionMonitorError: Error, Equatable, LocalizedError {
    case emptyEndpointList
    case invalidMonitoringInterval

    public var errorDescription: String? {
        switch self {
        case .emptyEndpointList:
            return "ConnectionMonitor requires at least one endpoint"
        case .invalidMonitoringInterval:
            return "Monitoring interval must be greater than zero"
        }
    }
}

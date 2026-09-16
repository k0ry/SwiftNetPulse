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

/// Stage of a live probe used for presentation. Not inferred from message text.
public enum ProbeStage: String, Equatable, Sendable {
    case dns
    case tcp
    case http
    case tls
    case traceroute
    case unknown
}

/// Additive typed failure data. Equality includes every field.
public struct ProbeFailureMetadata: Equatable, Sendable {
    public var stage: ProbeStage
    public var reasonCode: String
    public var arguments: [String]
    public var systemDomain: String?
    public var systemCode: Int?
    public var rawDetail: String?

    public init(
        stage: ProbeStage,
        reasonCode: String,
        arguments: [String] = [],
        systemDomain: String? = nil,
        systemCode: Int? = nil,
        rawDetail: String? = nil
    ) {
        self.stage = stage
        self.reasonCode = reasonCode
        self.arguments = arguments
        self.systemDomain = systemDomain
        self.systemCode = systemCode
        self.rawDetail = rawDetail
    }
}

public struct ProbeResult: Equatable, Sendable {
    public var endpoint: Endpoint
    public var outcome: ProbeOutcome
    public var resolvedIP: String?
    public var httpStatus: Int?
    public var body: Data
    public var timings: ProbeTimings
    public var traceroute: TracerouteResult?
    /// Typed classification for live transport failures. Nil on legacy values.
    public var failureMetadata: ProbeFailureMetadata?
    /// Typed traceroute unavailability from `check()`, when present.
    public var tracerouteFailureMetadata: ProbeFailureMetadata?

    public init(
        endpoint: Endpoint,
        outcome: ProbeOutcome,
        resolvedIP: String? = nil,
        httpStatus: Int? = nil,
        body: Data = Data(),
        timings: ProbeTimings,
        traceroute: TracerouteResult? = nil,
        failureMetadata: ProbeFailureMetadata? = nil,
        tracerouteFailureMetadata: ProbeFailureMetadata? = nil
    ) {
        self.endpoint = endpoint
        self.outcome = outcome
        self.resolvedIP = resolvedIP
        self.httpStatus = httpStatus
        self.body = body
        self.timings = timings
        self.traceroute = traceroute
        self.failureMetadata = failureMetadata
        self.tracerouteFailureMetadata = tracerouteFailureMetadata
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
    public var metadata: ProbeFailureMetadata?

    public init(
        endpoint: Endpoint,
        kind: ProbeFailureKind,
        httpStatus: Int? = nil,
        body: Data = Data(),
        timings: ProbeTimings,
        message: String? = nil,
        metadata: ProbeFailureMetadata? = nil
    ) {
        self.endpoint = endpoint
        self.kind = kind
        self.httpStatus = httpStatus
        self.body = body
        self.timings = timings
        self.message = message
        self.metadata = metadata
    }

    public init(result: ProbeResult) {
        endpoint = result.endpoint
        httpStatus = result.httpStatus
        body = result.body
        timings = result.timings
        metadata = result.failureMetadata
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

    /// Rebuilds presentation from structured fields. Does not probe the network
    /// and does not modify the stored `log`.
    public func localizedLog(using localization: ReportLocalization) -> String {
        LogFormatter.report(date: date, snapshot: snapshot, results: results, localization: localization)
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

    /// Default English compatibility rendering.
    public var log: String {
        LogFormatter.tracerouteLog(self, localization: .english)
    }

    /// Localizes owned labels. Arbitrary `.unavailable` messages stay opaque.
    public func localizedLog(using localization: ReportLocalization) -> String {
        LogFormatter.tracerouteLog(self, localization: localization)
    }
}

/// Companion to ``TracerouteResult`` that carries optional typed unavailability.
/// The legacy enum is unchanged so existing exhaustive switches keep compiling.
public struct TracerouteDetails: Equatable, Sendable {
    public var result: TracerouteResult
    public var unavailableMetadata: ProbeFailureMetadata?

    public init(result: TracerouteResult, unavailableMetadata: ProbeFailureMetadata? = nil) {
        self.result = result
        self.unavailableMetadata = unavailableMetadata
    }

    public var hopList: [TraceHop] { result.hopList }

    public var log: String {
        LogFormatter.tracerouteLog(result, localization: .english, metadata: unavailableMetadata)
    }

    public func localizedLog(using localization: ReportLocalization) -> String {
        LogFormatter.tracerouteLog(result, localization: localization, metadata: unavailableMetadata)
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

    /// Explicit presentation. Does not change ``errorDescription``.
    public func localizedDescription(using localization: ReportLocalization) -> String {
        switch self {
        case .emptyEndpointList:
            return L10n.text("error.empty_endpoints", localization)
        case .invalidMonitoringInterval:
            return L10n.text("error.invalid_interval", localization)
        }
    }
}

import Foundation

struct HTTPProbeResult {
    var status: Int?
    var body: Data
    var transportError: String?
    var failureMetadata: ProbeFailureMetadata?
    var httpsConnect: TimeInterval?
    var tls: TimeInterval?
    var httpResponse: TimeInterval?
    var metricBytes: Int
}

final class MetricsCollector: NSObject, URLSessionTaskDelegate {
    private let lock = NSLock()
    private var collected: URLSessionTaskMetrics?

    var metrics: URLSessionTaskMetrics? {
        lock.lock()
        defer { lock.unlock() }
        return collected
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.lock()
        collected = metrics
        lock.unlock()
    }
}

enum TransportErrorMapper {
    static func map(_ error: Error) -> (message: String, metadata: ProbeFailureMetadata) {
        let nsError = error as NSError
        let urlError = error as? URLError
        let code = urlError?.code ?? URLError.Code(rawValue: nsError.code)
        let domain = nsError.domain
        let usesURLDomain = domain == NSURLErrorDomain || urlError != nil
        let raw = error.localizedDescription

        func metadata(stage: ProbeStage, reason: String, arguments: [String] = []) -> ProbeFailureMetadata {
            ProbeFailureMetadata(
                stage: stage,
                reasonCode: reason,
                arguments: arguments,
                systemDomain: domain,
                systemCode: nsError.code,
                rawDetail: raw
            )
        }

        if usesURLDomain {
            switch code {
            case .timedOut:
                let meta = metadata(stage: .http, reason: ProbeReason.urlTimeout)
                return (L10n.englishCompatibilityMessage(meta), meta)
            case .cannotFindHost, .dnsLookupFailed:
                let meta = metadata(stage: .dns, reason: ProbeReason.urlDNS)
                return (L10n.englishCompatibilityMessage(meta), meta)
            case .cannotConnectToHost, .networkConnectionLost:
                let meta = metadata(stage: .tcp, reason: ProbeReason.urlConnect)
                return (L10n.englishCompatibilityMessage(meta), meta)
            case .notConnectedToInternet, .dataNotAllowed:
                let meta = metadata(stage: .http, reason: ProbeReason.urlOffline)
                return (L10n.englishCompatibilityMessage(meta), meta)
            case .cancelled:
                let meta = metadata(stage: .http, reason: ProbeReason.urlCancelled)
                return (L10n.englishCompatibilityMessage(meta), meta)
            case .secureConnectionFailed,
                 .serverCertificateUntrusted,
                 .serverCertificateHasBadDate,
                 .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid,
                 .clientCertificateRejected,
                 .clientCertificateRequired,
                 .appTransportSecurityRequiresSecureConnection:
                let meta = metadata(stage: .tls, reason: ProbeReason.urlTLS)
                return (L10n.englishCompatibilityMessage(meta), meta)
            default:
                break
            }
        }

        let meta = metadata(
            stage: .http,
            reason: ProbeReason.urlGeneric,
            arguments: [domain, String(nsError.code)]
        )
        return (L10n.englishCompatibilityMessage(meta), meta)
    }
}

enum HTTPProbe {
    static func fetch(url: URL, timeout: TimeInterval) async -> HTTPProbeResult {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = max(timeout, 0.001)
        configuration.timeoutIntervalForResource = max(timeout, 0.001)
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url, timeoutInterval: max(timeout, 0.001))
        request.httpMethod = "GET"
        let collector = MetricsCollector()

        do {
            let (data, response) = try await session.data(for: request, delegate: collector)
            let http = response as? HTTPURLResponse
            let timings = extract(collector.metrics)
            let nonHTTP = http == nil
            let metadata: ProbeFailureMetadata? = nonHTTP
                ? ProbeFailureMetadata(stage: .http, reasonCode: ProbeReason.nonHTTPResponse)
                : nil
            return HTTPProbeResult(
                status: http?.statusCode,
                body: data,
                transportError: nonHTTP ? L10n.englishCompatibilityMessage(metadata!) : nil,
                failureMetadata: metadata,
                httpsConnect: timings.connect,
                tls: timings.tls,
                httpResponse: timings.response,
                metricBytes: timings.bytes
            )
        } catch {
            let timings = extract(collector.metrics)
            let mapped = TransportErrorMapper.map(error)
            return HTTPProbeResult(
                status: nil,
                body: Data(),
                transportError: mapped.message,
                failureMetadata: mapped.metadata,
                httpsConnect: timings.connect,
                tls: timings.tls,
                httpResponse: timings.response,
                metricBytes: timings.bytes
            )
        }
    }

    private static func extract(_ metrics: URLSessionTaskMetrics?) -> (connect: TimeInterval?, tls: TimeInterval?, response: TimeInterval?, bytes: Int) {
        guard let transaction = metrics?.transactionMetrics.last else {
            return (nil, nil, nil, 0)
        }
        var connect: TimeInterval?
        if let start = transaction.connectStartDate, let end = transaction.connectEndDate {
            connect = end.timeIntervalSince(start)
        }
        var tls: TimeInterval?
        if let start = transaction.secureConnectionStartDate, let end = transaction.secureConnectionEndDate {
            tls = end.timeIntervalSince(start)
        }
        var response: TimeInterval?
        if let start = transaction.responseStartDate, let end = transaction.responseEndDate {
            response = end.timeIntervalSince(start)
        } else if let start = transaction.requestStartDate, let end = transaction.responseEndDate {
            response = end.timeIntervalSince(start)
        }
        let bytes = Int(transaction.countOfResponseBodyBytesReceived)
        return (connect, tls, response, bytes)
    }
}

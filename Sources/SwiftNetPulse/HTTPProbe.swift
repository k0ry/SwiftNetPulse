import Foundation

struct HTTPProbeResult {
    var status: Int?
    var body: Data
    var transportError: String?
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
            return HTTPProbeResult(
                status: http?.statusCode,
                body: data,
                transportError: http == nil ? "non-HTTP response" : nil,
                httpsConnect: timings.connect,
                tls: timings.tls,
                httpResponse: timings.response,
                metricBytes: timings.bytes
            )
        } catch {
            let timings = extract(collector.metrics)
            return HTTPProbeResult(
                status: nil,
                body: Data(),
                transportError: error.localizedDescription,
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

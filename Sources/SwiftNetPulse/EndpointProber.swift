import Foundation

protocol EndpointProbing: AnyObject {
    func probe(_ endpoint: Endpoint, includeTrace: Bool) async -> ProbeResult
}

protocol PathTracing: AnyObject {
    func trace(host: String, maxHops: Int) async -> TracerouteResult
}

final class LiveEndpointProber: EndpointProbing {
    private let tracer: PathTracing

    init(tracer: PathTracing) {
        self.tracer = tracer
    }

    func probe(_ endpoint: Endpoint, includeTrace: Bool) async -> ProbeResult {
        let startedAt = Date()
        var timings = ProbeTimings(total: 0)
        var resolvedIP: String?
        var traceroute: TracerouteResult?

        func finish(
            outcome: ProbeOutcome,
            status: Int? = nil,
            body: Data = Data()
        ) async -> ProbeResult {
            timings.total = Date().timeIntervalSince(startedAt)
            if includeTrace, let host = endpoint.url.host {
                traceroute = await tracer.trace(host: host, maxHops: 30)
            }
            return ProbeResult(
                endpoint: endpoint,
                outcome: outcome,
                resolvedIP: resolvedIP,
                httpStatus: status,
                body: body,
                timings: timings,
                traceroute: traceroute
            )
        }

        func remaining() -> TimeInterval {
            max(endpoint.timeout - Date().timeIntervalSince(startedAt), 0.001)
        }

        guard let host = endpoint.url.host, !host.isEmpty else {
            return await finish(outcome: .transportFailure("missing host"))
        }

        if DNSResolver.isIPAddress(host) {
            resolvedIP = host
        } else {
            let dnsStart = Date()
            do {
                resolvedIP = try DNSResolver.resolve(host)
                timings.dns = Date().timeIntervalSince(dnsStart)
            } catch {
                timings.dns = Date().timeIntervalSince(dnsStart)
                return await finish(outcome: .transportFailure("DNS failed for \(host)"))
            }
        }

        if Date().timeIntervalSince(startedAt) >= endpoint.timeout {
            return await finish(outcome: .transportFailure("timeout before TCP"))
        }

        let target = resolvedIP ?? host
        let tcp = await TCPProbe.connect(host: target, port: endpoint.port, timeout: remaining())
        timings.tcpConnect = tcp.duration
        if !tcp.succeeded {
            return await finish(outcome: .transportFailure("TCP \(target):\(endpoint.port) failed"))
        }

        if Date().timeIntervalSince(startedAt) >= endpoint.timeout {
            return await finish(outcome: .transportFailure("timeout before HTTP"))
        }

        let http = await HTTPProbe.fetch(url: endpoint.url, timeout: remaining())
        timings.httpsConnect = http.httpsConnect
        timings.tls = http.tls
        timings.httpResponse = http.httpResponse

        if let transportError = http.transportError {
            return await finish(outcome: .transportFailure(transportError))
        }
        guard let status = http.status else {
            return await finish(outcome: .transportFailure("no HTTP status"))
        }

        timings.transferSpeedBytesPerSecond = ProbeTimings.transferSpeed(
            bytes: http.body.count,
            responseDuration: timings.httpResponse
        )

        let matched = endpoint.rule.evaluate(status: status, body: http.body)
        return await finish(
            outcome: matched ? .success : .ruleMismatch,
            status: status,
            body: http.body
        )
    }
}

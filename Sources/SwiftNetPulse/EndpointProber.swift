import Foundation

protocol EndpointProbing: AnyObject {
    func probe(_ endpoint: Endpoint, includeTrace: Bool) async -> ProbeResult
}

protocol PathTracing: AnyObject {
    func trace(host: String, maxHops: Int) async -> TracerouteDetails
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
        var tracerouteFailureMetadata: ProbeFailureMetadata?

        func finish(
            outcome: ProbeOutcome,
            status: Int? = nil,
            body: Data = Data(),
            metadata: ProbeFailureMetadata? = nil
        ) async -> ProbeResult {
            timings.total = Date().timeIntervalSince(startedAt)
            if includeTrace, let host = endpoint.url.host {
                let details = await tracer.trace(host: host, maxHops: 30)
                traceroute = details.result
                tracerouteFailureMetadata = details.unavailableMetadata
            }
            return ProbeResult(
                endpoint: endpoint,
                outcome: outcome,
                resolvedIP: resolvedIP,
                httpStatus: status,
                body: body,
                timings: timings,
                traceroute: traceroute,
                failureMetadata: metadata,
                tracerouteFailureMetadata: tracerouteFailureMetadata
            )
        }

        func remaining() -> TimeInterval {
            max(endpoint.timeout - Date().timeIntervalSince(startedAt), 0.001)
        }

        guard let host = endpoint.url.host, !host.isEmpty else {
            let metadata = ProbeFailureMetadata(stage: .dns, reasonCode: ProbeReason.missingHost)
            return await finish(
                outcome: .transportFailure(L10n.englishCompatibilityMessage(metadata)),
                metadata: metadata
            )
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
                let metadata = ProbeFailureMetadata(
                    stage: .dns,
                    reasonCode: ProbeReason.dnsFailed,
                    arguments: [host]
                )
                return await finish(
                    outcome: .transportFailure(L10n.englishCompatibilityMessage(metadata)),
                    metadata: metadata
                )
            }
        }

        if Date().timeIntervalSince(startedAt) >= endpoint.timeout {
            let metadata = ProbeFailureMetadata(stage: .tcp, reasonCode: ProbeReason.timeoutBeforeTCP)
            return await finish(
                outcome: .transportFailure(L10n.englishCompatibilityMessage(metadata)),
                metadata: metadata
            )
        }

        let target = resolvedIP ?? host
        let tcp = await TCPProbe.connect(host: target, port: endpoint.port, timeout: remaining())
        timings.tcpConnect = tcp.duration
        if !tcp.succeeded {
            let metadata = ProbeFailureMetadata(
                stage: .tcp,
                reasonCode: ProbeReason.tcpFailed,
                arguments: [target, String(endpoint.port)]
            )
            return await finish(
                outcome: .transportFailure(L10n.englishCompatibilityMessage(metadata)),
                metadata: metadata
            )
        }

        if Date().timeIntervalSince(startedAt) >= endpoint.timeout {
            let metadata = ProbeFailureMetadata(stage: .http, reasonCode: ProbeReason.timeoutBeforeHTTP)
            return await finish(
                outcome: .transportFailure(L10n.englishCompatibilityMessage(metadata)),
                metadata: metadata
            )
        }

        let http = await HTTPProbe.fetch(url: endpoint.url, timeout: remaining())
        timings.httpsConnect = http.httpsConnect
        timings.tls = http.tls
        timings.httpResponse = http.httpResponse

        if let transportError = http.transportError {
            return await finish(
                outcome: .transportFailure(transportError),
                metadata: http.failureMetadata
            )
        }
        guard let status = http.status else {
            let metadata = ProbeFailureMetadata(stage: .http, reasonCode: ProbeReason.noHTTPStatus)
            return await finish(
                outcome: .transportFailure(L10n.englishCompatibilityMessage(metadata)),
                metadata: metadata
            )
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

import Foundation

enum LogFormatter {
    static func report(
        date: Date,
        snapshot: NetworkSnapshot,
        results: [ProbeResult],
        localization: ReportLocalization = .english
    ) -> String {
        var lines: [String] = []
        lines.append(L10n.text("report.title", localization))
        lines.append(L10n.text("report.date", localization, iso(date)))
        if let pathType = snapshot.pathType {
            lines.append(L10n.text("report.network_type", localization, L10n.pathType(pathType, localization: localization)))
        }
        if let ip = snapshot.localIPv4 {
            lines.append(L10n.text("report.local_ip", localization, ip))
        }
        if !snapshot.dnsServers.isEmpty {
            lines.append(L10n.text("report.dns_servers", localization, snapshot.dnsServers.joined(separator: ", ")))
        }
        if let vpn = snapshot.vpnDetected {
            let flag = L10n.text(vpn ? "report.vpn.yes" : "report.vpn.no", localization)
            lines.append(L10n.text("report.vpn", localization, flag))
        }
        lines.append("")

        for result in results {
            lines.append(contentsOf: endpointSection(result, localization: localization))
            lines.append("")
        }
        lines.append(L10n.text("report.finished", localization))
        return lines.joined(separator: "\n")
    }

    static func tracerouteLog(
        _ result: TracerouteResult,
        localization: ReportLocalization = .english,
        metadata: ProbeFailureMetadata? = nil
    ) -> String {
        switch result {
        case .unavailable(let message):
            let detail: String
            if let metadata {
                detail = L10n.failureSummary(metadata, localization: localization)
            } else {
                detail = message
            }
            return L10n.text("trace.unavailable", localization, detail)
        case .hops(let hops):
            var lines = [L10n.text("trace.start", localization)]
            for hop in hops {
                lines.append(format(hop: hop, localization: localization))
            }
            return lines.joined(separator: "\n")
        }
    }

    static func format(hop: TraceHop, localization: ReportLocalization = .english) -> String {
        let marker = L10n.text("trace.timeout_marker", localization)
        let label = hop.address ?? hop.hostname ?? marker
        let rtt: String
        if let value = hop.rtt {
            rtt = L10n.milliseconds(value, digits: 2, localization: localization)
        } else {
            rtt = marker
        }
        return L10n.text("trace.hop", localization, String(hop.index), label, rtt)
    }

    private static func endpointSection(_ result: ProbeResult, localization: ReportLocalization) -> [String] {
        let host = result.endpoint.url.host ?? result.endpoint.url.absoluteString
        let separator = L10n.text("endpoint.separator", localization)
        var lines = [
            separator,
            L10n.text("endpoint.url", localization, result.endpoint.url.absoluteString),
            L10n.text("endpoint.host", localization, host),
            separator,
        ]

        let dnsFailed = result.failureMetadata?.stage == .dns
        if let ip = result.resolvedIP {
            if let dns = formatMs(result.timings.dns, localization: localization) {
                lines.append(L10n.text("dns.resolved_timed", localization, ip, dns))
            } else {
                lines.append(L10n.text("dns.resolved", localization, ip))
            }
        } else if dnsFailed {
            if let dns = formatMs(result.timings.dns, localization: localization) {
                lines.append(L10n.text("dns.failed_timed", localization, dns))
            } else {
                lines.append(L10n.text("dns.failed", localization))
            }
        }

        if let tcp = result.timings.tcpConnect {
            let formatted = L10n.milliseconds(tcp, digits: 1, localization: localization)
            let tcpFailed = result.failureMetadata?.stage == .tcp && !result.succeeded
            if tcpFailed {
                lines.append(L10n.text("tcp.failed", localization, formatted))
            } else {
                lines.append(L10n.text("tcp.connected", localization, formatted))
            }
        }

        if let connect = result.timings.httpsConnect {
            lines.append(L10n.text("https.connect", localization, L10n.milliseconds(connect, digits: 1, localization: localization)))
        }
        if let tls = result.timings.tls {
            lines.append(L10n.text("tls.handshake", localization, L10n.milliseconds(tls, digits: 1, localization: localization)))
        }
        if let status = result.httpStatus {
            lines.append(L10n.text("http.status", localization, String(status)))
        }
        if let response = result.timings.httpResponse {
            lines.append(L10n.text("http.response", localization, L10n.milliseconds(response, digits: 1, localization: localization)))
        }
        lines.append(L10n.text("timing.total", localization, L10n.milliseconds(result.timings.total, digits: 1, localization: localization)))
        if let speed = result.timings.transferSpeedBytesPerSecond {
            let amount = L10n.decimal(speed, digits: 0, localization: localization)
            let unit = L10n.text("unit.bytes_per_second", localization)
            lines.append(L10n.text("timing.speed", localization, amount, unit))
        }
        switch result.outcome {
        case .success:
            lines.append(L10n.text("outcome.success", localization))
        case .ruleMismatch:
            lines.append(L10n.text("outcome.rule_mismatch", localization))
        case .transportFailure(let reason):
            let detail: String
            if let metadata = result.failureMetadata {
                detail = L10n.failureSummary(metadata, localization: localization)
            } else {
                detail = reason
            }
            lines.append(L10n.text("outcome.transport_failure", localization, detail))
            if let raw = result.failureMetadata?.rawDetail, raw != detail, !raw.isEmpty {
                lines.append(L10n.text("raw.system_detail", localization, raw))
            }
        }
        if !result.body.isEmpty {
            let preview = String(data: result.body.prefix(240), encoding: .utf8)
                ?? L10n.text("body.binary", localization)
            lines.append(L10n.text("body.preview", localization))
            lines.append(preview)
        }
        if let trace = result.traceroute {
            lines.append(tracerouteLog(trace, localization: localization, metadata: result.tracerouteFailureMetadata))
        }
        return lines
    }

    private static func formatMs(_ value: TimeInterval?, localization: ReportLocalization) -> String? {
        value.map { L10n.milliseconds($0, digits: 1, localization: localization) }
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

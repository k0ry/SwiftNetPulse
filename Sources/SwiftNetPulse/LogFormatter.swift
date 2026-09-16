import Foundation

enum LogFormatter {
    static func report(date: Date, snapshot: NetworkSnapshot, results: [ProbeResult]) -> String {
        var lines: [String] = []
        lines.append("NETWORK DIAGNOSIS")
        lines.append("Date: \(iso(date))")
        if let pathType = snapshot.pathType {
            lines.append("Network type: \(pathType)")
        }
        if let ip = snapshot.localIPv4 {
            lines.append("Local IP: \(ip)")
        }
        if !snapshot.dnsServers.isEmpty {
            lines.append("DNS servers: \(snapshot.dnsServers.joined(separator: ", "))")
        }
        if let vpn = snapshot.vpnDetected {
            lines.append("VPN detected: \(vpn ? "YES" : "NO")")
        }
        lines.append("")

        for result in results {
            lines.append(contentsOf: endpointSection(result))
            lines.append("")
        }
        lines.append("DIAGNOSIS FINISHED")
        return lines.joined(separator: "\n")
    }

    static func tracerouteLog(_ result: TracerouteResult) -> String {
        switch result {
        case .unavailable(let message):
            return "Traceroute unavailable: \(message)"
        case .hops(let hops):
            var lines = ["Trace start"]
            for hop in hops {
                lines.append(format(hop: hop))
            }
            return lines.joined(separator: "\n")
        }
    }

    static func format(hop: TraceHop) -> String {
        let label = hop.address ?? hop.hostname ?? "*"
        let rtt: String
        if let value = hop.rtt {
            rtt = String(format: "%.2f ms", value * 1000)
        } else {
            rtt = "*"
        }
        return "\(hop.index): \(label) \(rtt) |"
    }

    private static func endpointSection(_ result: ProbeResult) -> [String] {
        let host = result.endpoint.url.host ?? result.endpoint.url.absoluteString
        var lines = [
            "-----------------------------------------------",
            "Endpoint: \(result.endpoint.url.absoluteString)",
            "Host: \(host)",
            "-----------------------------------------------",
        ]
        if let ip = result.resolvedIP {
            let dns = formatMs(result.timings.dns)
            lines.append("DNS: \(ip)\(dns.map { " (\($0))" } ?? "")")
        } else if case .transportFailure(let reason) = result.outcome, reason.contains("DNS") {
            lines.append("DNS: failed\(formatMs(result.timings.dns).map { " (\($0))" } ?? "")")
        }

        if let tcp = result.timings.tcpConnect {
            if case .transportFailure(let reason) = result.outcome, reason.contains("TCP") {
                lines.append("TCP: failed in \(ms(tcp))")
            } else {
                lines.append("TCP: connected in \(ms(tcp))")
            }
        }

        if let connect = result.timings.httpsConnect {
            lines.append("HTTPS connect: \(ms(connect))")
        }
        if let tls = result.timings.tls {
            lines.append("TLS handshake: \(ms(tls))")
        }
        if let status = result.httpStatus {
            lines.append("HTTP status: \(status)")
        }
        if let response = result.timings.httpResponse {
            lines.append("HTTP response: \(ms(response))")
        }
        lines.append("Total: \(ms(result.timings.total))")
        if let speed = result.timings.transferSpeedBytesPerSecond {
            lines.append(String(format: "Speed: %.0f B/s", speed))
        }
        switch result.outcome {
        case .success:
            lines.append("Outcome: success")
        case .ruleMismatch:
            lines.append("Outcome: rule mismatch")
        case .transportFailure(let reason):
            lines.append("Outcome: transport failure (\(reason))")
        }
        if !result.body.isEmpty {
            let preview = String(data: result.body.prefix(240), encoding: .utf8) ?? "<binary>"
            lines.append("Body preview:")
            lines.append(preview)
        }
        if let trace = result.traceroute {
            lines.append(tracerouteLog(trace))
        }
        return lines
    }

    private static func formatMs(_ value: TimeInterval?) -> String? {
        value.map { ms($0) }
    }

    private static func ms(_ value: TimeInterval) -> String {
        String(format: "%.1f ms", value * 1000)
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

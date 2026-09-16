import Darwin
import Foundation

enum HopOutcome {
    case timeout
    case hop(address: String, rtt: TimeInterval, destination: Bool)
}

enum PathTraceCollector {
    static func collect(maxHops: Int, probe: (Int) -> HopOutcome) -> TracerouteResult {
        let hopsLimit = max(maxHops, 0)
        guard hopsLimit > 0 else {
            return .hops([])
        }
        var hops: [TraceHop] = []
        for ttl in 1 ... hopsLimit {
            switch probe(ttl) {
            case .timeout:
                hops.append(TraceHop(index: ttl))
            case .hop(let address, let rtt, let destination):
                hops.append(TraceHop(index: ttl, address: address, rtt: rtt))
                if destination {
                    return .hops(hops)
                }
            }
        }
        return .hops(hops)
    }
}

final class ICMPPathTracer: PathTracing {
    var hopTimeout: TimeInterval
    var maxHopsDefault: Int
    var socketFactory: () -> Int32

    init(
        hopTimeout: TimeInterval = 1,
        maxHopsDefault: Int = 30,
        socketFactory: @escaping () -> Int32 = {
            socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        }
    ) {
        self.hopTimeout = hopTimeout
        self.maxHopsDefault = maxHopsDefault
        self.socketFactory = socketFactory
    }

    func trace(host: String, maxHops: Int) async -> TracerouteDetails {
        await Task.detached { [hopTimeout, socketFactory] in
            ICMPPathTracer.run(
                host: host,
                maxHops: maxHops,
                hopTimeout: hopTimeout,
                socketFactory: socketFactory
            )
        }.value
    }

    static func run(
        host: String,
        maxHops: Int,
        hopTimeout: TimeInterval,
        socketFactory: () -> Int32
    ) -> TracerouteDetails {
        let fd = socketFactory()
        guard fd >= 0 else {
            let metadata = ProbeFailureMetadata(stage: .traceroute, reasonCode: ProbeReason.socket)
            return TracerouteDetails(
                result: .unavailable(message: L10n.englishCompatibilityMessage(metadata)),
                unavailableMetadata: metadata
            )
        }
        defer { close(fd) }

        let destinationIP: String
        do {
            destinationIP = try DNSResolver.resolve(host)
        } catch {
            let metadata = ProbeFailureMetadata(
                stage: .traceroute,
                reasonCode: ProbeReason.tracerouteDNS,
                arguments: [host]
            )
            return TracerouteDetails(
                result: .unavailable(message: L10n.englishCompatibilityMessage(metadata)),
                unavailableMetadata: metadata
            )
        }

        guard let destination = IPv4Address(destinationIP) else {
            let metadata = ProbeFailureMetadata(stage: .traceroute, reasonCode: ProbeReason.ipv4Only)
            return TracerouteDetails(
                result: .unavailable(message: L10n.englishCompatibilityMessage(metadata)),
                unavailableMetadata: metadata
            )
        }

        let identifier = UInt16.random(in: 1 ... .max)
        let collected = PathTraceCollector.collect(maxHops: maxHops) { ttl in
            probeHop(
                fd: fd,
                destination: destination,
                ttl: ttl,
                identifier: identifier,
                timeout: hopTimeout
            )
        }
        return TracerouteDetails(result: collected)
    }

    private static func probeHop(
        fd: Int32,
        destination: IPv4Address,
        ttl: Int,
        identifier: UInt16,
        timeout: TimeInterval
    ) -> HopOutcome {
        var ttlValue = Int32(ttl)
        setsockopt(fd, IPPROTO_IP, IP_TTL, &ttlValue, socklen_t(MemoryLayout<Int32>.size))

        var packet = ICMPEcho.make(identifier: identifier, sequence: UInt16(ttl))
        let start = Date()
        let sent = packet.withUnsafeBytes { buffer -> Int in
            destination.withSockaddr { addr, length in
                sendto(fd, buffer.baseAddress, buffer.count, 0, addr, length)
            }
        }
        guard sent > 0 else { return .timeout }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { break }
            var pollfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let millis = Int32(max(remaining * 1000, 1))
            let ready = poll(&pollfd, 1, millis)
            guard ready > 0 else { continue }

            var buffer = [UInt8](repeating: 0, count: 512)
            var storage = sockaddr_storage()
            var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let received = withUnsafeMutablePointer(to: &storage) { pointer -> Int in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { addr in
                    recvfrom(fd, &buffer, buffer.count, 0, addr, &length)
                }
            }
            guard received > 0 else { continue }
            let rtt = Date().timeIntervalSince(start)
            if let isDestination = ICMPEcho.parse(bytes: buffer, count: received, identifier: identifier, sequence: UInt16(ttl)) {
                let address = IPv4Address.stringify(storage) ?? destination.dotted
                return .hop(address: address, rtt: rtt, destination: isDestination)
            }
        }
        return .timeout
    }
}

private struct IPv4Address {
    var dotted: String
    var saddr: in_addr

    init?(_ dotted: String) {
        var addr = in_addr()
        guard dotted.withCString({ inet_pton(AF_INET, $0, &addr) }) == 1 else {
            return nil
        }
        self.dotted = dotted
        self.saddr = addr
    }

    func withSockaddr<T>(_ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
        var addr = sockaddr_in()
        addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr = saddr
        return withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                body(sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    static func stringify(_ storage: sockaddr_storage) -> String? {
        var storage = storage
        return withUnsafePointer(to: &storage) { pointer -> String? in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { addr in
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                switch Int32(addr.pointee.sa_family) {
                case AF_INET:
                    addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { v4 in
                        var copy = v4.pointee
                        _ = inet_ntop(AF_INET, &copy.sin_addr, &buffer, socklen_t(buffer.count))
                    }
                    return String(cString: buffer)
                default:
                    return nil
                }
            }
        }
    }
}

private enum ICMPEcho {
    static func make(identifier: UInt16, sequence: UInt16) -> Data {
        var bytes: [UInt8] = [
            8, 0, 0, 0,
            UInt8(identifier >> 8), UInt8(identifier & 0xFF),
            UInt8(sequence >> 8), UInt8(sequence & 0xFF),
            0x4E, 0x44, 0x54, 0x52,
        ]
        let sum = checksum(bytes)
        bytes[2] = UInt8(sum >> 8)
        bytes[3] = UInt8(sum & 0xFF)
        return Data(bytes)
    }

    static func parse(bytes: [UInt8], count: Int, identifier: UInt16, sequence: UInt16) -> Bool? {
        guard count >= 28 else { return nil }
        let ipHeaderLength = Int(bytes[0] & 0x0F) * 4
        guard ipHeaderLength >= 20, count >= ipHeaderLength + 8 else { return nil }
        let type = bytes[ipHeaderLength]
        if type == 0 {
            return match(bytes, offset: ipHeaderLength, identifier: identifier, sequence: sequence).map { _ in true }
        }
        if type == 11 {
            let innerOffset = ipHeaderLength + 8
            guard count > innerOffset + 20 else { return nil }
            let innerIPLength = Int(bytes[innerOffset] & 0x0F) * 4
            let icmpOffset = innerOffset + innerIPLength
            return match(bytes, offset: icmpOffset, identifier: identifier, sequence: sequence).map { _ in false }
        }
        return nil
    }

    private static func match(_ bytes: [UInt8], offset: Int, identifier: UInt16, sequence: UInt16) -> Bool? {
        guard bytes.count >= offset + 8 else { return nil }
        let id = UInt16(bytes[offset + 4]) << 8 | UInt16(bytes[offset + 5])
        let seq = UInt16(bytes[offset + 6]) << 8 | UInt16(bytes[offset + 7])
        guard id == identifier, seq == sequence else { return nil }
        return true
    }

    private static func checksum(_ bytes: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var index = 0
        while index + 1 < bytes.count {
            sum += UInt32(bytes[index]) << 8 | UInt32(bytes[index + 1])
            index += 2
        }
        if index < bytes.count {
            sum += UInt32(bytes[index]) << 8
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return ~UInt16(sum & 0xFFFF)
    }
}

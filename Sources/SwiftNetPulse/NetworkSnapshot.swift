import Darwin
import Foundation
import Network

protocol NetworkSnapshotProviding: AnyObject {
    func snapshot() async -> NetworkSnapshot
}

final class LiveNetworkSnapshotProvider: NetworkSnapshotProviding {
    func snapshot() async -> NetworkSnapshot {
        let pathType = await currentPathType()
        return NetworkSnapshot(
            pathType: pathType,
            localIPv4: firstNonLoopbackIPv4(),
            dnsServers: dnsServers(),
            vpnDetected: vpnPresent()
        )
    }

    private func currentPathType() async -> String? {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "SwiftNetPulse.path")
            let lock = NSLock()
            var resumed = false
            @Sendable func finish(_ value: String?) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                monitor.cancel()
                continuation.resume(returning: value)
            }
            monitor.pathUpdateHandler = { path in
                if path.usesInterfaceType(.wifi) {
                    finish("wifi")
                } else if path.usesInterfaceType(.cellular) {
                    finish("cellular")
                } else if path.usesInterfaceType(.wiredEthernet) {
                    finish("ethernet")
                } else if path.usesInterfaceType(.loopback) {
                    finish("loopback")
                } else if path.status == .satisfied {
                    finish("other")
                } else {
                    finish("unsatisfied")
                }
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 0.4) {
                finish(nil)
            }
        }
    }

    private func firstNonLoopbackIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            if isUp, !isLoopback, let addr = current.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                let ip = String(cString: hostname)
                if !ip.isEmpty { return ip }
            }
            cursor = current.pointee.ifa_next
        }
        return nil
    }

    private func vpnPresent() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            if let name = current.pointee.ifa_name {
                let interface = String(cString: name)
                if interface.hasPrefix("utun") || interface.hasPrefix("ipsec") || interface.hasPrefix("ppp") {
                    return true
                }
            }
            cursor = current.pointee.ifa_next
        }
        return false
    }

    private func dnsServers() -> [String] {
        guard let text = try? String(contentsOfFile: "/etc/resolv.conf", encoding: .utf8) else {
            return []
        }
        return text.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2, parts[0] == "nameserver" else { return nil }
            return String(parts[1])
        }
    }
}

import Darwin
import Foundation

enum DNSResolver {
    static func isIPAddress(_ host: String) -> Bool {
        var v4 = in_addr()
        var v6 = in6_addr()
        return host.withCString { inet_pton(AF_INET, $0, &v4) == 1 }
            || host.withCString { inet_pton(AF_INET6, $0, &v6) == 1 }
    }

    static func resolve(_ host: String) throws -> String {
        if isIPAddress(host) {
            return host
        }
        var hints = addrinfo()
        hints.ai_socktype = SOCK_STREAM
        var info: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &info)
        guard status == 0, let first = info else {
            throw DNSError.failed(host)
        }
        defer { freeaddrinfo(info) }
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let current = cursor {
            if let ip = stringify(current.pointee.ai_addr, family: current.pointee.ai_family) {
                return ip
            }
            cursor = current.pointee.ai_next
        }
        throw DNSError.failed(host)
    }

    private static func stringify(_ addr: UnsafePointer<sockaddr>?, family: Int32) -> String? {
        guard let addr else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        switch family {
        case AF_INET:
            addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer in
                var copy = pointer.pointee
                _ = inet_ntop(AF_INET, &copy.sin_addr, &buffer, socklen_t(buffer.count))
            }
        case AF_INET6:
            addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer in
                var copy = pointer.pointee
                _ = inet_ntop(AF_INET6, &copy.sin6_addr, &buffer, socklen_t(buffer.count))
            }
        default:
            return nil
        }
        return String(cString: buffer)
    }

    enum DNSError: Error {
        case failed(String)
    }
}

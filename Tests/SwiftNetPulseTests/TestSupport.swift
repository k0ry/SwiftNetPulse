import Combine
import Darwin
import Foundation
import Network
import XCTest
@testable import SwiftNetPulse

func sampleURL(_ host: String = "example.test", port: UInt16? = nil, path: String = "/") -> URL {
    var components = URLComponents()
    components.scheme = "http"
    components.host = host
    components.port = port.map(Int.init)
    components.path = path
    return components.url!
}

func sampleEndpoint(
    host: String = "example.test",
    port: UInt16? = nil,
    rule: ProbeRule = .anyData,
    timeout: TimeInterval = 2,
    traceOnCheck: Bool = false
) -> Endpoint {
    Endpoint(url: sampleURL(host, port: port), rule: rule, timeout: timeout, traceOnCheck: traceOnCheck)
}

func sampleResult(
    endpoint: Endpoint? = nil,
    outcome: ProbeOutcome = .success,
    status: Int? = 200,
    body: Data = Data(),
    timings: ProbeTimings = ProbeTimings(total: 0.01),
    traceroute: TracerouteResult? = nil
) -> ProbeResult {
    ProbeResult(
        endpoint: endpoint ?? sampleEndpoint(),
        outcome: outcome,
        resolvedIP: "127.0.0.1",
        httpStatus: status,
        body: body,
        timings: timings,
        traceroute: traceroute
    )
}

final class ScriptedProber: EndpointProbing {
    private let lock = NSLock()
    private var script: [ProbeResult]
    private(set) var calls: [(url: URL, includeTrace: Bool)] = []
    var delay: TimeInterval = 0
    var onProbe: ((Endpoint, Bool) -> Void)?

    init(results: [ProbeResult]) {
        self.script = results
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls.count
    }

    func probe(_ endpoint: Endpoint, includeTrace: Bool) async -> ProbeResult {
        lock.lock()
        calls.append((endpoint.url, includeTrace))
        let index = calls.count - 1
        lock.unlock()
        onProbe?(endpoint, includeTrace)
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if index < script.count {
            var result = script[index]
            result.endpoint = endpoint
            return result
        }
        return sampleResult(endpoint: endpoint, outcome: .success)
    }
}

final class RecordingTracer: PathTracing {
    private let lock = NSLock()
    var details: TracerouteDetails
    private(set) var hosts: [String] = []

    var result: TracerouteResult {
        get { details.result }
        set { details.result = newValue }
    }

    init(result: TracerouteResult = .hops([TraceHop(index: 1, address: "10.0.0.1", rtt: 0.01)])) {
        self.details = TracerouteDetails(result: result)
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return hosts.count
    }

    func resetHosts() {
        lock.lock()
        hosts.removeAll()
        lock.unlock()
    }

    func trace(host: String, maxHops: Int) async -> TracerouteDetails {
        lock.lock()
        hosts.append(host)
        lock.unlock()
        return details
    }
}

final class FixedSnapshot: NetworkSnapshotProviding {
    var value = NetworkSnapshot(pathType: "wifi", localIPv4: "192.168.31.57", dnsServers: ["192.168.31.1"], vpnDetected: false)

    func snapshot() async -> NetworkSnapshot { value }
}

func makeMonitor(
    endpoints: [Endpoint],
    prober: EndpointProbing,
    tracer: PathTracing = RecordingTracer(),
    snapshot: NetworkSnapshotProviding = FixedSnapshot(),
    localization: ReportLocalization = .english
) throws -> ConnectionMonitor {
    try ConnectionMonitor(
        endpoints: endpoints,
        prober: prober,
        tracer: tracer,
        snapshotProvider: snapshot,
        localization: localization
    )
}

final class LocalTCPListener {
    private var listener: NWListener?
    private(set) var port: UInt16 = 0

    func start() throws {
        let listener = try NWListener(using: .tcp, on: 0)
        let started = DispatchSemaphore(value: 0)
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, _, _ in
                connection.cancel()
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .ready = state, let port = listener.port?.rawValue {
                self?.port = port
                started.signal()
            }
        }
        listener.start(queue: .global())
        self.listener = listener
        let wait = started.wait(timeout: .now() + 2)
        guard wait == .success, port > 0 else {
            throw NSError(domain: "LocalTCPListener", code: 1)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}

final class LocalHTTPServer {
    private var listenFD: Int32 = -1
    private(set) var port: UInt16 = 0
    var statusCode: Int = 200
    var body: Data = Data()
    var delay: TimeInterval = 0
    private let lock = NSLock()
    private var running = false

    func start() throws {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { throw NSError(domain: "LocalHTTPServer", code: 1) }
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        let bindStatus = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindStatus == 0, listen(fd, 16) == 0 else {
            close(fd)
            throw NSError(domain: "LocalHTTPServer", code: 2)
        }
        var bound = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameStatus = withUnsafeMutablePointer(to: &bound) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard nameStatus == 0 else {
            close(fd)
            throw NSError(domain: "LocalHTTPServer", code: 3)
        }
        listenFD = fd
        port = UInt16(bigEndian: bound.sin_port)
        running = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        lock.lock()
        running = false
        let fd = listenFD
        listenFD = -1
        lock.unlock()
        if fd >= 0 {
            shutdown(fd, SHUT_RDWR)
            close(fd)
        }
    }

    deinit { stop() }

    private func acceptLoop() {
        while true {
            lock.lock()
            let runningNow = running
            let fd = listenFD
            lock.unlock()
            guard runningNow, fd >= 0 else { return }
            var addr = sockaddr_in()
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let client = withUnsafeMutablePointer(to: &addr) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(fd, $0, &length)
                }
            }
            guard client >= 0 else { continue }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handle(client)
            }
        }
    }

    private func handle(_ client: Int32) {
        defer { close(client) }
        var buffer = [UInt8](repeating: 0, count: 4096)
        _ = recv(client, &buffer, buffer.count, 0)
        lock.lock()
        let delay = self.delay
        let status = statusCode
        let body = self.body
        lock.unlock()
        if delay > 0 {
            Thread.sleep(forTimeInterval: delay)
        }
        let reason = status == 204 ? "No Content" : "OK"
        var header = "HTTP/1.1 \(status) \(reason)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var payload = Data(header.utf8)
        payload.append(body)
        payload.withUnsafeBytes { raw in
            _ = send(client, raw.baseAddress, payload.count, 0)
        }
    }
}

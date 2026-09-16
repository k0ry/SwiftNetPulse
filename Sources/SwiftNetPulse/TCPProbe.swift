import Foundation
import Network

struct TCPProbeResult: Equatable {
    var succeeded: Bool
    var duration: TimeInterval
}

enum TCPProbe {
    static func connect(host: String, port: UInt16, timeout: TimeInterval) async -> TCPProbeResult {
        guard timeout > 0, let nwPort = NWEndpoint.Port(rawValue: port) else {
            return TCPProbeResult(succeeded: false, duration: 0)
        }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        let connection = NWConnection(to: endpoint, using: .tcp)
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var finished = false
            let start = Date()
            @Sendable func complete(_ succeeded: Bool) {
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                connection.cancel()
                continuation.resume(
                    returning: TCPProbeResult(
                        succeeded: succeeded,
                        duration: Date().timeIntervalSince(start)
                    )
                )
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    complete(true)
                case .failed, .cancelled:
                    complete(false)
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue.global(qos: .userInitiated))
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                complete(false)
            }
        }
    }
}

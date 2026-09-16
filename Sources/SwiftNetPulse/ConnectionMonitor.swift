import Combine
import Foundation

/// Probes a list of HTTP endpoints, publishes Combine events, and can trace IPv4 routes.
///
/// The existing ``init(endpoints:)`` keeps English presentation. Pass
/// ``ReportLocalization`` to select Russian or another supported table for newly
/// generated `DiagnosisReport.log` values. Structured results and publishers are
/// independent of language.
public final class ConnectionMonitor {
    private let endpoints: [Endpoint]
    private let prober: EndpointProbing
    private let tracer: PathTracing
    private let snapshotProvider: NetworkSnapshotProviding
    private let localization: ReportLocalization
    private let queue: DispatchQueue

    private let eventsSubject = PassthroughSubject<ProbeEvent, Never>()
    private let failuresSubject = PassthroughSubject<ProbeFailure, Never>()

    private let stateLock = NSLock()
    private var timer: DispatchSourceTimer?
    private var inFlight = false

    public var events: AnyPublisher<ProbeEvent, Never> {
        eventsSubject.eraseToAnyPublisher()
    }

    public var failures: AnyPublisher<ProbeFailure, Never> {
        failuresSubject.eraseToAnyPublisher()
    }

    /// Creates a monitor with English report rendering.
    public convenience init(endpoints: [Endpoint]) throws {
        try self.init(endpoints: endpoints, localization: .english)
    }

    /// Creates a monitor whose `check()` reports use `localization`.
    public convenience init(endpoints: [Endpoint], localization: ReportLocalization) throws {
        let tracer = ICMPPathTracer()
        try self.init(
            endpoints: endpoints,
            prober: LiveEndpointProber(tracer: tracer),
            tracer: tracer,
            snapshotProvider: LiveNetworkSnapshotProvider(),
            localization: localization
        )
    }

    init(
        endpoints: [Endpoint],
        prober: EndpointProbing,
        tracer: PathTracing,
        snapshotProvider: NetworkSnapshotProviding,
        queue: DispatchQueue = DispatchQueue(label: "SwiftNetPulse.monitor"),
        localization: ReportLocalization = .english
    ) throws {
        guard !endpoints.isEmpty else {
            throw ConnectionMonitorError.emptyEndpointList
        }
        self.endpoints = endpoints
        self.prober = prober
        self.tracer = tracer
        self.snapshotProvider = snapshotProvider
        self.localization = localization
        self.queue = queue
    }

    public func check() async -> DiagnosisReport {
        let date = Date()
        let snapshot = await snapshotProvider.snapshot()
        let results = await runProbes(includeTrace: true)
        let log = LogFormatter.report(date: date, snapshot: snapshot, results: results, localization: localization)
        return DiagnosisReport(date: date, snapshot: snapshot, results: results, log: log)
    }

    public func startMonitoring(every interval: TimeInterval) throws {
        guard interval > 0 else {
            throw ConnectionMonitorError.invalidMonitoringInterval
        }
        stopMonitoring()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        stateLock.lock()
        self.timer = timer
        stateLock.unlock()
        timer.resume()
    }

    public func stopMonitoring() {
        stateLock.lock()
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
        stateLock.unlock()
    }

    /// Legacy adapter. Returns the unchanged ``TracerouteResult`` enum.
    public func traceroute(to host: String, maxHops: Int = 30) async -> TracerouteResult {
        await tracerouteDetails(to: host, maxHops: maxHops).result
    }

    /// Detailed traceroute including typed unavailability metadata.
    public func tracerouteDetails(to host: String, maxHops: Int = 30) async -> TracerouteDetails {
        await tracer.trace(host: host, maxHops: maxHops)
    }

    private func tick() {
        stateLock.lock()
        if inFlight {
            stateLock.unlock()
            return
        }
        inFlight = true
        stateLock.unlock()

        Task { [weak self] in
            guard let self else { return }
            let results = await self.runProbes(includeTrace: false)
            for result in results where !result.succeeded {
                self.queue.async {
                    self.failuresSubject.send(ProbeFailure(result: result))
                }
            }
            self.queue.async {
                self.stateLock.lock()
                self.inFlight = false
                self.stateLock.unlock()
            }
        }
    }

    private func runProbes(includeTrace: Bool) async -> [ProbeResult] {
        var results: [ProbeResult] = []
        for endpoint in endpoints {
            let shouldTrace = includeTrace && endpoint.traceOnCheck
            let result = await prober.probe(endpoint, includeTrace: shouldTrace)
            emit(result)
            results.append(result)
        }
        return results
    }

    private func emit(_ result: ProbeResult) {
        let event: ProbeEvent = result.succeeded ? .success(result) : .failure(result)
        eventsSubject.send(event)
    }

    deinit {
        stopMonitoring()
    }
}

import Foundation

/// The SDK's optOut() stops new capture, but its existing queue can still flush.
/// This gate also cancels in-flight requests and prevents an old SDK run from sending.
final class AnalyticsNetworkGate: @unchecked Sendable {
    static let shared = AnalyticsNetworkGate()
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var hosts: Set<String> = []
    private var sessions: [UUID: URLSession] = [:]

    func configure(generation: UInt64, hosts: Set<String>) {
        let old = lock.withLock {
            self.generation = generation
            self.hosts = hosts
            let old = Array(sessions.values)
            sessions.removeAll()
            return old
        }
        for session in old { session.invalidateAndCancel() }
    }

    func allows(_ generation: UInt64) -> Bool {
        lock.withLock { self.generation == generation && !hosts.isEmpty }
    }

    func register(_ session: URLSession, id: UUID, generation: UInt64, host: String) -> Bool {
        lock.withLock {
            guard self.generation == generation, hosts.contains(host) else { return false }
            sessions[id] = session
            return true
        }
    }

    func unregister(_ id: UUID) { lock.withLock { _ = sessions.removeValue(forKey: id) } }
}

final class AnalyticsTransport: URLProtocol, URLSessionTaskDelegate, @unchecked Sendable {
    static let generationHeader = "X-Tessera-Analytics-Generation"
    private let requestID = UUID()
    private let lock = NSLock()
    private var session: URLSession?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, url.scheme == "https", let host = url.host,
              let rawGeneration = request.value(forHTTPHeaderField: Self.generationHeader),
              let generation = UInt64(rawGeneration) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            return
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = []
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        lock.withLock { self.session = session }
        guard AnalyticsNetworkGate.shared.register(session, id: requestID, generation: generation, host: host) else {
            session.invalidateAndCancel()
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            return
        }
        var outgoing = request
        outgoing.setValue(nil, forHTTPHeaderField: Self.generationHeader)
        session.dataTask(with: outgoing) { [weak self] data, response, error in
            guard let self else { return }
            defer {
                AnalyticsNetworkGate.shared.unregister(self.requestID)
                session.finishTasksAndInvalidate()
            }
            guard AnalyticsNetworkGate.shared.allows(generation) else {
                self.client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
                return
            }
            if let error { self.client?.urlProtocol(self, didFailWithError: error); return }
            if let response { self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
            if let data { self.client?.urlProtocol(self, didLoad: data) }
            self.client?.urlProtocolDidFinishLoading(self)
        }.resume()
    }

    override func stopLoading() {
        let old = lock.withLock { let old = session; session = nil; return old }
        old?.invalidateAndCancel()
        AnalyticsNetworkGate.shared.unregister(requestID)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        // Never forward telemetry, tokens or a POST body to a redirected origin.
        completionHandler(nil)
    }
}

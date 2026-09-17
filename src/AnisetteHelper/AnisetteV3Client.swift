import CryptoKit
import Foundation
#if os(macOS)
import Darwin
#endif

enum AnisetteURLPolicy {
    static func isValidServerURL(_ url: URL) -> Bool {
        isValidSecureURL(url, schemes: ["https"])
    }

    static func isValidProvisioningURL(_ url: URL) -> Bool {
        isValidSecureURL(url, schemes: ["https"])
    }

    static func isValidWebSocketURL(_ url: URL) -> Bool {
        isValidSecureURL(url, schemes: ["wss"])
    }

    static func isValidSecureURLForRequest(_ url: URL) -> Bool {
        isValidSecureURL(url, schemes: ["https"])
    }

    static func isValidRedirect(_ url: URL, matching expectedURL: URL) -> Bool {
        guard isValidSecureURL(url, schemes: [expectedURL.scheme?.lowercased() ?? ""]),
              let expectedHost = expectedURL.host,
              let host = url.host,
              host.caseInsensitiveCompare(expectedHost) == .orderedSame,
              effectivePort(for: url) == effectivePort(for: expectedURL) else {
            return false
        }
        return true
    }

    private static func effectivePort(for url: URL) -> Int? {
        if let port = url.port {
            return port
        }
        switch url.scheme?.lowercased() {
        case "https", "wss":
            return 443
        case "http", "ws":
            return 80
        default:
            return nil
        }
    }

    private static func isValidSecureURL(
        _ url: URL,
        schemes: Set<String>
    ) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              schemes.contains(scheme),
              let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty,
              url.user == nil,
              url.password == nil else {
            return false
        }
        return true
    }
}

private enum AnisetteResponseLimits {
    static let maxHTTPResponseBytes = 1_048_576
    static let maxWebSocketMessageBytes = 1_048_576
}

private enum AnisetteSessionConfiguration {
    static func isolated(
        basedOn baseConfiguration: URLSessionConfiguration? = nil
    ) -> URLSessionConfiguration {
        let configuration: URLSessionConfiguration
        if let baseConfiguration,
           let copiedConfiguration = baseConfiguration.copy() as? URLSessionConfiguration {
            configuration = copiedConfiguration
        } else {
            configuration = .ephemeral
        }
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.httpAdditionalHeaders = [:]
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return configuration
    }
}

private final class RedirectValidationDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let expectedURL: URL

    init(expectedURL: URL) {
        self.expectedURL = expectedURL
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url,
              AnisetteURLPolicy.isValidRedirect(url, matching: expectedURL) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

private final class WebSocketLifecycle: @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    private let session: URLSession
    private let lock = NSLock()
    private var didFinish = false

    init(task: URLSessionWebSocketTask, session: URLSession) {
        self.task = task
        self.session = session
    }

    func cancelForTaskCancellation() {
        finish(with: .goingAway)
    }

    func closeNormally() {
        finish(with: .normalClosure)
    }

    private func finish(with closeCode: URLSessionWebSocketTask.CloseCode) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        lock.unlock()

        task.cancel(with: closeCode, reason: nil)
        session.invalidateAndCancel()
    }
}

private enum AnisetteClientInfo {
    // Apple's GSA edge (gsa.apple.com/grandslam/GsService2) returns an
    // immediate HTML 503 for any sign-in whose X-Mme-Client-Info names
    // com.apple.dt.Xcode, regardless of the version suffix. com.apple.akd
    // is the daemon that actually performs this request on a real Mac, and
    // is accepted. See altstoreio/AltStore#1790, fixed upstream in
    // AltServer 1.7.6.
    private static let akdVersion = "1.0"

    static var current: String {
        let version = macOSVersion
        return "<\(hardwareModel)> <macOS;\(version.product);\(version.build)> "
            + "<com.apple.AuthKit/1 (com.apple.akd/\(akdVersion))>"
    }

    private static let hardwareModel = sysctlString("hw.model") ?? "Mac"

    private static let macOSVersion: (product: String, build: String) = {
        let processInfo = ProcessInfo.processInfo
        let operatingSystemVersion = processInfo.operatingSystemVersion
        let fallbackProduct = [
            String(operatingSystemVersion.majorVersion),
            String(operatingSystemVersion.minorVersion),
            operatingSystemVersion.patchVersion > 0
                ? String(operatingSystemVersion.patchVersion)
                : nil,
        ]
        .compactMap { $0 }
        .joined(separator: ".")

        let product = sysctlString("kern.osproductversion")
            ?? systemVersionValue(forKey: "ProductVersion")
            ?? fallbackProduct
        let build = sysctlString("kern.osversion")
            ?? systemVersionValue(forKey: "ProductBuildVersion")
            ?? "unknown"
        return (product: product, build: build)
    }()

    private static func sysctlString(_ name: String) -> String? {
#if os(macOS)
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: size)
        let result = buffer.withUnsafeMutableBytes { bytes in
            sysctlbyname(name, bytes.baseAddress, &size, nil, 0)
        }
        guard result == 0 else {
            return nil
        }

        let value = buffer.prefix(size).prefix(while: { $0 != 0 })
        guard !value.isEmpty else {
            return nil
        }
        return String(decoding: value, as: UTF8.self)
#else
        return nil
#endif
    }

    private static func systemVersionValue(forKey key: String) -> String? {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/SystemVersion.plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data,
                  format: nil
              ) as? [String: Any],
              let value = plist[key] as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }
}

struct AnisetteV3Identity: Codable, Sendable {
    let serverURL: URL
    var clientInfo: String
    let userAgent: String
    let serialNumber: String
    let localUserID: String
    let deviceID: String
    var provisioningData: String?

    private enum CodingKeys: String, CodingKey {
        case serverURL
        case clientInfo
        case userAgent
        case serialNumber
        case localUserID
        case deviceID
        case provisioningData
    }

    init(
        serverURL: URL,
        clientInfo: String,
        userAgent: String,
        serialNumber: String,
        localUserID: String,
        deviceID: String,
        provisioningData: String? = nil
    ) {
        self.serverURL = serverURL
        self.clientInfo = clientInfo
        self.userAgent = userAgent
        self.serialNumber = serialNumber
        self.localUserID = localUserID
        self.deviceID = deviceID
        self.provisioningData = provisioningData
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let decodedServerURL = try values.decode(URL.self, forKey: .serverURL)
        guard AnisetteURLPolicy.isValidServerURL(decodedServerURL) else {
            throw DecodingError.dataCorruptedError(
                forKey: .serverURL,
                in: values,
                debugDescription: "Anisette server URL must use HTTPS without userinfo and include a host."
            )
        }
        serverURL = decodedServerURL
        _ = try values.decodeIfPresent(String.self, forKey: .clientInfo)
        clientInfo = AnisetteClientInfo.current
        userAgent = try values.decode(String.self, forKey: .userAgent)
        serialNumber = try values.decode(String.self, forKey: .serialNumber)
        localUserID = try values.decode(String.self, forKey: .localUserID)
        deviceID = try values.decode(String.self, forKey: .deviceID)
        provisioningData = try values.decodeIfPresent(String.self, forKey: .provisioningData)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serverURL, forKey: .serverURL)
        try container.encode(AnisetteClientInfo.current, forKey: .clientInfo)
        try container.encode(userAgent, forKey: .userAgent)
        try container.encode(serialNumber, forKey: .serialNumber)
        try container.encode(localUserID, forKey: .localUserID)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encodeIfPresent(provisioningData, forKey: .provisioningData)
    }

    mutating func refreshClientInfo() {
        clientInfo = AnisetteClientInfo.current
    }

    static func create(serverURL: URL) -> AnisetteV3Identity {
        let randomData = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let localUserID = SHA256.hash(data: randomData)
            .map { String(format: "%02X", $0) }
            .joined()

        return AnisetteV3Identity(
            serverURL: serverURL,
            clientInfo: AnisetteClientInfo.current,
            userAgent: "akd/1.0 CFNetwork/808.1.4",
            serialNumber: "0",
            localUserID: localUserID,
            deviceID: UUID().uuidString.uppercased(),
            provisioningData: nil
        )
    }
}

struct AnisetteV3Client: Sendable {
    enum ClientError: LocalizedError {
        case invalidResponse(String)
        case http(Int, URL?)
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse(let step):
                return "Invalid anisette response during \(step)."
            case .http(let statusCode, let url):
                let location = url?.absoluteString ?? "unknown URL"
                return "Anisette request failed with HTTP \(statusCode) at \(location)."
            case .server(let message):
                return "Anisette server error: \(message)"
            }
        }
    }

    private let session: URLSession

    init(session: URLSession? = nil) {
        let configuration = AnisetteSessionConfiguration.isolated(
            basedOn: session?.configuration
        )
        self.session = URLSession(configuration: configuration)
    }

    func provision(_ savedIdentity: AnisetteV3Identity) async throws -> AnisetteV3Identity {
        var identity = savedIdentity
        identity.refreshClientInfo()
        guard AnisetteURLPolicy.isValidServerURL(identity.serverURL) else {
            throw ClientError.invalidResponse("server URL")
        }
        let provisioningURLs = try await fetchProvisioningURLs(for: identity)
        var webSocketComponents = URLComponents()
        webSocketComponents.scheme = "wss"
        webSocketComponents.host = identity.serverURL.host
        webSocketComponents.port = identity.serverURL.port
        webSocketComponents.path = "/v3/provisioning_session"
        guard let webSocketURL = webSocketComponents.url,
              AnisetteURLPolicy.isValidWebSocketURL(webSocketURL) else {
            throw ClientError.invalidResponse("websocket URL")
        }
        var request = URLRequest(url: webSocketURL)
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue(identity.clientInfo, forHTTPHeaderField: "X-Mme-Client-Info")
        let webSocketDelegate = RedirectValidationDelegate(expectedURL: webSocketURL)
        let webSocketSession = URLSession(
            configuration: AnisetteSessionConfiguration.isolated(
                basedOn: session.configuration
            ),
            delegate: webSocketDelegate,
            delegateQueue: nil
        )
        let task = webSocketSession.webSocketTask(with: request)
        task.maximumMessageSize = AnisetteResponseLimits.maxWebSocketMessageBytes
        let lifecycle = WebSocketLifecycle(task: task, session: webSocketSession)
        defer {
            lifecycle.closeNormally()
        }

        return try await withTaskCancellationHandler(operation: {
            guard !Task.isCancelled else {
                throw CancellationError()
            }
            task.resume()
            return try await runProvisioningSession(
                identity: identity,
                provisioningURLs: provisioningURLs,
                task: task
            )
        }, onCancel: {
            lifecycle.cancelForTaskCancellation()
        })
    }

    private func runProvisioningSession(
        identity: AnisetteV3Identity,
        provisioningURLs: (start: URL, end: URL),
        task: URLSessionWebSocketTask
    ) async throws -> AnisetteV3Identity {
        while true {
            let message = try await task.receive()
            let data: Data
            switch message {
            case .string(let text):
                guard text.utf8.count <= AnisetteResponseLimits.maxWebSocketMessageBytes,
                      let stringData = text.data(using: .utf8) else {
                    throw ClientError.invalidResponse("websocket message too large")
                }
                data = stringData

            case .data(let messageData):
                guard messageData.count <= AnisetteResponseLimits.maxWebSocketMessageBytes else {
                    throw ClientError.invalidResponse("websocket message too large")
                }
                throw ClientError.invalidResponse("websocket")

            @unknown default:
                throw ClientError.invalidResponse("websocket")
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? String else {
                throw ClientError.invalidResponse("websocket")
            }

            switch result {
            case "GiveIdentifier":
                try await task.sendJSON(["identifier": identity.localUserID])

            case "GiveStartProvisioningData":
                let spim = try await startProvisioning(
                    identity,
                    at: provisioningURLs.start
                )
                try await task.sendJSON(["spim": spim])

            case "GiveEndProvisioningData":
                guard let cpim = json["cpim"] as? String else {
                    throw ClientError.invalidResponse("end request")
                }
                let result = try await finishProvisioning(
                    identity,
                    at: provisioningURLs.end,
                    cpim: cpim
                )
                try await task.sendJSON(result)

            case "ProvisioningSuccess":
                guard let provisioningData = json["adi_pb"] as? String else {
                    throw ClientError.invalidResponse("success")
                }
                var provisionedIdentity = identity
                provisionedIdentity.provisioningData = provisioningData
                return provisionedIdentity

            case "Timeout":
                throw ClientError.server("Provisioning timed out.")

            default:
                let message = json["message"] as? String ?? result
                throw ClientError.server(message)
            }
        }
    }

    func fetchHeaders(for savedIdentity: AnisetteV3Identity) async throws -> [String: String] {
        var identity = savedIdentity
        identity.refreshClientInfo()
        guard AnisetteURLPolicy.isValidServerURL(identity.serverURL),
              let provisioningData = identity.provisioningData else {
            throw ClientError.invalidResponse("saved identity")
        }

        var request = URLRequest(
            url: identity.serverURL.appendingPathComponent("v3/get_headers")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(identity.clientInfo, forHTTPHeaderField: "X-Mme-Client-Info")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "identifier": identity.localUserID,
            "adi_pb": provisioningData,
        ])

        let data = try await boundedData(
            for: request,
            expectedURL: identity.serverURL
        )

        guard let headers = try JSONSerialization.jsonObject(with: data)
                as? [String: String],
              headers["X-Apple-I-MD"]?.isEmpty == false,
              headers["X-Apple-I-MD-M"]?.isEmpty == false else {
            throw try serverError(from: data, step: "header generation")
        }

        return [
            "X-Apple-Client-Time": Date.anisetteTimestamp,
            "X-Mme-Client-Info": identity.clientInfo,
            "X-Apple-I-TimeZone": TimeZone.current.abbreviation() ?? "UTC",
            "X-Apple-Locale": Locale.current.identifier,
            "X-Apple-I-MD": headers["X-Apple-I-MD"]!,
            "X-Apple-I-MD-LU": identity.localUserID,
            "X-Apple-I-MD-M": headers["X-Apple-I-MD-M"]!,
            "X-Apple-I-MD-RINFO": headers["X-Apple-I-MD-RINFO"] ?? "17106176",
            "X-Apple-I-SRL-NO": identity.serialNumber,
            "X-Mme-Device-Id": identity.deviceID,
        ]
    }

    private func fetchProvisioningURLs(
        for identity: AnisetteV3Identity
    ) async throws -> (start: URL, end: URL) {
        var request = appleRequest(
            for: identity,
            url: URL(string: "https://gsa.apple.com/grandslam/GsService2/lookup")!
        )
        request.httpMethod = "GET"

        let data = try await boundedData(
            for: request,
            expectedURL: request.url!
        )

        guard let plist = try PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as? [String: Any],
              let urls = plist["urls"] as? [String: String],
              let startString = urls["midStartProvisioning"],
              let endString = urls["midFinishProvisioning"],
              let start = URL(string: startString),
              let end = URL(string: endString),
              AnisetteURLPolicy.isValidProvisioningURL(start),
              AnisetteURLPolicy.isValidProvisioningURL(end) else {
            throw ClientError.invalidResponse("lookup")
        }
        return (start, end)
    }

    private func startProvisioning(
        _ identity: AnisetteV3Identity,
        at url: URL
    ) async throws -> String {
        let data = try await sendAppleProvisioningRequest(
            identity,
            url: url,
            values: [:]
        )
        guard let response = try plistResponse(from: data),
              let spim = response["spim"] as? String else {
            throw ClientError.invalidResponse("start provisioning")
        }
        return spim
    }

    private func finishProvisioning(
        _ identity: AnisetteV3Identity,
        at url: URL,
        cpim: String
    ) async throws -> [String: String] {
        let data = try await sendAppleProvisioningRequest(
            identity,
            url: url,
            values: ["cpim": cpim]
        )
        guard let response = try plistResponse(from: data),
              let ptm = response["ptm"] as? String,
              let token = response["tk"] as? String else {
            throw ClientError.invalidResponse("finish provisioning")
        }
        return ["ptm": ptm, "tk": token]
    }

    private func sendAppleProvisioningRequest(
        _ identity: AnisetteV3Identity,
        url: URL,
        values: [String: String]
    ) async throws -> Data {
        guard AnisetteURLPolicy.isValidProvisioningURL(url) else {
            throw ClientError.invalidResponse("provisioning URL")
        }
        var request = appleRequest(for: identity, url: url)
        request.httpMethod = "POST"
        request.httpBody = try PropertyListSerialization.data(
            fromPropertyList: [
                "Header": [String: String](),
                "Request": values,
            ],
            format: .xml,
            options: 0
        )

        return try await boundedData(for: request, expectedURL: url)
    }

    private func boundedData(
        for request: URLRequest,
        expectedURL: URL
    ) async throws -> Data {
        guard let requestURL = request.url,
              AnisetteURLPolicy.isValidSecureURLForRequest(requestURL),
              AnisetteURLPolicy.isValidRedirect(requestURL, matching: expectedURL) else {
            throw ClientError.invalidResponse("request URL")
        }

        let delegate = RedirectValidationDelegate(expectedURL: expectedURL)
        let (bytes, response) = try await session.bytes(for: request, delegate: delegate)
        do {
            try validate(response, expectedURL: expectedURL)
        } catch {
            bytes.task.cancel()
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            bytes.task.cancel()
            throw ClientError.invalidResponse("HTTP")
        }
        let contentLength = httpResponse.expectedContentLength
        if contentLength > Int64(AnisetteResponseLimits.maxHTTPResponseBytes) {
            bytes.task.cancel()
            throw ClientError.invalidResponse("response too large")
        }

        var data = Data()
        if contentLength > 0 {
            data.reserveCapacity(min(
                Int(contentLength),
                AnisetteResponseLimits.maxHTTPResponseBytes
            ))
        }
        for try await byte in bytes {
            if data.count >= AnisetteResponseLimits.maxHTTPResponseBytes {
                bytes.task.cancel()
                throw ClientError.invalidResponse("response too large")
            }
            data.append(byte)
        }
        return data
    }

    private func appleRequest(
        for identity: AnisetteV3Identity,
        url: URL
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(identity.clientInfo, forHTTPHeaderField: "X-Mme-Client-Info")
        request.setValue(identity.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue(identity.localUserID, forHTTPHeaderField: "X-Mme-Device-Id")
        request.setValue(Date.anisetteTimestamp, forHTTPHeaderField: "X-Apple-I-Client-Time")
        request.setValue(Locale.current.identifier, forHTTPHeaderField: "X-Apple-Locale")
        request.setValue(
            TimeZone.current.abbreviation() ?? "UTC",
            forHTTPHeaderField: "X-Apple-I-TimeZone"
        )
        return request
    }

    private func plistResponse(from data: Data) throws -> [String: Any]? {
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as? [String: Any]
        return plist?["Response"] as? [String: Any]
    }

    private func validate(_ response: URLResponse, expectedURL: URL) throws {
        guard let response = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse("HTTP")
        }
        guard let responseURL = response.url,
              AnisetteURLPolicy.isValidRedirect(responseURL, matching: expectedURL) else {
            throw ClientError.invalidResponse("response URL")
        }
        guard (200..<300).contains(response.statusCode) else {
            throw ClientError.http(response.statusCode, response.url)
        }
    }

    private func serverError(from data: Data, step: String) throws -> ClientError {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return .server(message)
        }
        return .invalidResponse(step)
    }
}

private extension URLSessionWebSocketTask {
    func sendJSON(_ object: [String: String]) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else {
            throw AnisetteV3Client.ClientError.invalidResponse("JSON encoding")
        }
        try await send(.string(text))
    }
}

private extension Date {
    static var anisetteTimestamp: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}

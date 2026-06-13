import CryptoKit
import Foundation

struct AnisetteV3Identity: Codable {
    let serverURL: URL
    let clientInfo: String
    let userAgent: String
    let serialNumber: String
    let localUserID: String
    let deviceID: String
    var provisioningData: String?

    static func create(serverURL: URL) -> AnisetteV3Identity {
        let randomData = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let localUserID = SHA256.hash(data: randomData)
            .map { String(format: "%02X", $0) }
            .joined()

        return AnisetteV3Identity(
            serverURL: serverURL,
            clientInfo: "<MacBookPro13,2> <macOS;13.1;22C65> <com.apple.AuthKit/1 (com.apple.dt.Xcode/3594.4.19)>",
            userAgent: "akd/1.0 CFNetwork/808.1.4",
            serialNumber: "0",
            localUserID: localUserID,
            deviceID: UUID().uuidString.uppercased(),
            provisioningData: nil
        )
    }
}

struct AnisetteV3Client {
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

    init(session: URLSession = .shared) {
        self.session = session
    }

    func provision(_ identity: AnisetteV3Identity) async throws -> AnisetteV3Identity {
        let provisioningURLs = try await fetchProvisioningURLs(for: identity)
        let webSocketURL = URL(
            string: "wss://\(identity.serverURL.host!)/v3/provisioning_session"
        )!
        var request = URLRequest(url: webSocketURL)
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        let task = session.webSocketTask(with: request)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        while true {
            let message = try await task.receive()
            guard case .string(let text) = message,
                  let data = text.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
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

    func fetchHeaders(for identity: AnisetteV3Identity) async throws -> [String: String] {
        guard let provisioningData = identity.provisioningData else {
            throw ClientError.invalidResponse("saved identity")
        }

        var request = URLRequest(
            url: identity.serverURL.appendingPathComponent("v3/get_headers")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "identifier": identity.localUserID,
            "adi_pb": provisioningData,
        ])

        let (data, response) = try await session.data(for: request)
        try validate(response)

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

        let (data, response) = try await session.data(for: request)
        try validate(response)

        guard let plist = try PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as? [String: Any],
              let urls = plist["urls"] as? [String: String],
              let startString = urls["midStartProvisioning"],
              let endString = urls["midFinishProvisioning"],
              let start = URL(string: startString),
              let end = URL(string: endString) else {
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

        let (data, response) = try await session.data(for: request)
        try validate(response)
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

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse("HTTP")
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

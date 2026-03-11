import Foundation

public struct VoiceUpdateChecklistItem: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let isCompleted: Bool

    public init(id: String, title: String, isCompleted: Bool) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }

    public init(_ item: ChecklistItem) {
        self.id = item.id.uuidString
        self.title = item.title
        self.isCompleted = item.isCompleted
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isCompleted = "is_completed"
    }
}

public struct VoiceUpdateRequest: Encodable, Equatable, Sendable {
    public static let supportedAudioMime = "audio/wav"

    public let audioBase64: String
    public let audioMime: String
    public let languageHint: String?
    public let checklistItems: [VoiceUpdateChecklistItem]?

    public init(
        audioBase64: String,
        languageHint: String? = nil,
        checklistItems: [VoiceUpdateChecklistItem]? = nil
    ) {
        self.audioBase64 = audioBase64
        self.audioMime = Self.supportedAudioMime
        self.languageHint = languageHint
        self.checklistItems = checklistItems
    }

    public init(
        audioData: Data,
        languageHint: String? = nil,
        checklistItems: [VoiceUpdateChecklistItem]? = nil
    ) {
        self.init(
            audioBase64: audioData.base64EncodedString(),
            languageHint: languageHint,
            checklistItems: checklistItems
        )
    }

    public init(
        audioData: Data,
        languageHint: String? = nil,
        checklistItems: [ChecklistItem]
    ) {
        self.init(
            audioBase64: audioData.base64EncodedString(),
            languageHint: languageHint,
            checklistItems: checklistItems.map(VoiceUpdateChecklistItem.init)
        )
    }

    enum CodingKeys: String, CodingKey {
        case audioBase64 = "audio_base64"
        case audioMime = "audio_mime"
        case languageHint = "language_hint"
        case checklistItems = "checklist_items"
    }
}

public enum VoiceUpdateOperation: Decodable, Equatable, Sendable {
    case complete(id: String)
    case add(title: String)
    case edit(id: String, title: String?, isCompleted: Bool?)
    case remove(id: String)
    case move(id: String, toIndex: Int)

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case title
        case isCompleted = "is_completed"
        case toIndex = "to_index"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "complete":
            let id = try container.decode(String.self, forKey: .id)
            self = .complete(id: id)
        case "add":
            let title = try container.decode(String.self, forKey: .title)
            self = .add(title: title)
        case "edit":
            let id = try container.decode(String.self, forKey: .id)
            let title = try container.decodeIfPresent(String.self, forKey: .title)
            let isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted)
            self = .edit(id: id, title: title, isCompleted: isCompleted)
        case "remove":
            let id = try container.decode(String.self, forKey: .id)
            self = .remove(id: id)
        case "move":
            let id = try container.decode(String.self, forKey: .id)
            let toIndex = try container.decode(Int.self, forKey: .toIndex)
            self = .move(id: id, toIndex: toIndex)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported operation type: \(type)"
            )
        }
    }
}

public struct VoiceUpdateResponse: Decodable, Equatable, Sendable {
    public let transcript: String
    public let operations: [VoiceUpdateOperation]
    public let confidence: Double
    public let transactionId: String?

    enum CodingKeys: String, CodingKey {
        case transcript
        case operations
        case confidence
        case transactionId = "transaction_id"
    }
}

public enum VoiceUpdateClientError: Error, Equatable {
    case invalidEndpoint
    case nonHTTPResponse
    case requestFailed(statusCode: Int, code: String?, message: String?)
    case decodingFailed
}

private struct VoiceUpdateErrorEnvelope: Decodable {
    struct ErrorPayload: Decodable {
        let code: String
        let message: String
    }

    let error: ErrorPayload
}

public final class VoiceUpdateClient {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
    }

    public func sendVoiceUpdate(_ request: VoiceUpdateRequest) async throws -> VoiceUpdateResponse {
        guard let url = URL(string: "/voice-update", relativeTo: baseURL) else {
            throw VoiceUpdateClientError.invalidEndpoint
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceUpdateClientError.nonHTTPResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorEnvelope = try? decoder.decode(VoiceUpdateErrorEnvelope.self, from: data)
            throw VoiceUpdateClientError.requestFailed(
                statusCode: httpResponse.statusCode,
                code: errorEnvelope?.error.code,
                message: errorEnvelope?.error.message
            )
        }

        do {
            return try decoder.decode(VoiceUpdateResponse.self, from: data)
        } catch {
            throw VoiceUpdateClientError.decodingFailed
        }
    }
}

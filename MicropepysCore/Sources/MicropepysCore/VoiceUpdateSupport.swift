import Foundation

public struct VoiceOperationMappingResult: Equatable, Sendable {
    public let operations: [ChecklistOperation]
    public let warnings: [String]

    public init(operations: [ChecklistOperation], warnings: [String]) {
        self.operations = operations
        self.warnings = warnings
    }
}

public enum VoiceUpdateOperationMapper {
    public static func map(
        _ voiceOperations: [VoiceUpdateOperation],
        onto initialItems: [ChecklistItem]
    ) -> VoiceOperationMappingResult {
        var simulatedItems = initialItems
        var mappedOperations: [ChecklistOperation] = []
        var warnings: [String] = []

        for operation in voiceOperations {
            switch operation {
            case let .complete(id):
                guard let uuid = UUID(uuidString: id) else {
                    warnings.append("Skipped complete for invalid UUID: \(id)")
                    continue
                }
                guard let index = simulatedItems.firstIndex(where: { $0.id == uuid }) else {
                    warnings.append("Skipped complete for unknown item id: \(id)")
                    continue
                }
                guard !simulatedItems[index].isCompleted else { continue }

                simulatedItems[index].isCompleted = true
                mappedOperations.append(.complete(id: uuid))

            case let .add(title):
                simulatedItems.append(ChecklistItem(title: title))
                mappedOperations.append(.add(title: title))

            case let .edit(id, title, isCompleted):
                guard let uuid = UUID(uuidString: id) else {
                    warnings.append("Skipped edit for invalid UUID: \(id)")
                    continue
                }
                guard let index = simulatedItems.firstIndex(where: { $0.id == uuid }) else {
                    warnings.append("Skipped edit for unknown item id: \(id)")
                    continue
                }

                let previous = simulatedItems[index]
                var updated = previous
                if let title {
                    updated.title = title
                }
                if let isCompleted {
                    updated.isCompleted = isCompleted
                }
                guard updated != previous else { continue }

                simulatedItems[index] = updated
                mappedOperations.append(.edit(id: uuid, title: title, isCompleted: isCompleted))

            case let .remove(id):
                guard let uuid = UUID(uuidString: id) else {
                    warnings.append("Skipped remove for invalid UUID: \(id)")
                    continue
                }
                guard let index = simulatedItems.firstIndex(where: { $0.id == uuid }) else {
                    warnings.append("Skipped remove for unknown item id: \(id)")
                    continue
                }

                simulatedItems.remove(at: index)
                mappedOperations.append(.remove(id: uuid))

            case let .move(id, toIndex):
                guard let uuid = UUID(uuidString: id) else {
                    warnings.append("Skipped move for invalid UUID: \(id)")
                    continue
                }
                guard let sourceIndex = simulatedItems.firstIndex(where: { $0.id == uuid }) else {
                    warnings.append("Skipped move for unknown item id: \(id)")
                    continue
                }

                let source = IndexSet(integer: sourceIndex)
                guard source.first != toIndex, source.first != toIndex - 1 else { continue }

                var movingItems: [ChecklistItem] = []
                for index in source.sorted(by: >) {
                    movingItems.insert(simulatedItems.remove(at: index), at: 0)
                }

                let destination = max(0, min(toIndex, simulatedItems.count))
                simulatedItems.insert(contentsOf: movingItems, at: destination)
                mappedOperations.append(.move(source: source, destination: destination))
            }
        }

        return VoiceOperationMappingResult(operations: mappedOperations, warnings: warnings)
    }
}

public enum VoiceUpdateFailureKind: Equatable, Sendable {
    case invalidEndpoint
    case nonHTTPResponse
    case requestFailed(statusCode: Int, code: String?, message: String?)
    case decodingFailed
    case transport(description: String)
}

public enum VoiceUpdateErrorInterpreter {
    public static func kind(for error: Error) -> VoiceUpdateFailureKind {
        if let clientError = error as? VoiceUpdateClientError {
            switch clientError {
            case .invalidEndpoint:
                return .invalidEndpoint
            case .nonHTTPResponse:
                return .nonHTTPResponse
            case let .requestFailed(statusCode, code, message):
                return .requestFailed(statusCode: statusCode, code: code, message: message)
            case .decodingFailed:
                return .decodingFailed
            }
        }

        return .transport(description: error.localizedDescription)
    }

    public static func message(for error: Error) -> String {
        switch kind(for: error) {
        case .invalidEndpoint:
            return "Invalid /voice-update endpoint."
        case .nonHTTPResponse:
            return "Backend returned a non-HTTP response."
        case let .requestFailed(statusCode, code, message):
            if statusCode == 422, code == "stt_audio_decode_failed" {
                return "Backend could not decode this WAV file. Re-export the fixture as a standard PCM WAV file and try again."
            }
            return "HTTP \(statusCode) \(code ?? "backend_error"): \(message ?? "No message")"
        case .decodingFailed:
            return "Backend response could not be decoded."
        case let .transport(description):
            return description
        }
    }
}

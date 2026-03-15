import XCTest
@testable import MicropepysCore

final class VoiceUpdateSupportTests: XCTestCase {
    func testOperationMapperConvertsSupportedOperationsIntoChecklistBatch() {
        let first = ChecklistItem(id: UUID(), title: "Passport", isCompleted: false)
        let second = ChecklistItem(id: UUID(), title: "Laundry", isCompleted: false)

        let result = VoiceUpdateOperationMapper.map(
            [
                .complete(id: first.id.uuidString),
                .edit(id: second.id.uuidString, title: "Start the laundry", isCompleted: nil),
                .add(title: "Schedule a meeting")
            ],
            onto: [first, second]
        )

        XCTAssertEqual(
            result.operations,
            [
                .complete(id: first.id),
                .edit(id: second.id, title: "Start the laundry", isCompleted: nil),
                .add(title: "Schedule a meeting")
            ]
        )
        XCTAssertEqual(result.warnings, [])
    }

    func testOperationMapperSkipsUnknownAndInvalidIdentifiersWithWarnings() {
        let existing = ChecklistItem(id: UUID(), title: "Passport", isCompleted: false)
        let unknownID = UUID()

        let result = VoiceUpdateOperationMapper.map(
            [
                .complete(id: "not-a-uuid"),
                .remove(id: unknownID.uuidString),
                .complete(id: existing.id.uuidString)
            ],
            onto: [existing]
        )

        XCTAssertEqual(result.operations, [.complete(id: existing.id)])
        XCTAssertEqual(
            result.warnings,
            [
                "Skipped complete for invalid UUID: not-a-uuid",
                "Skipped remove for unknown item id: \(unknownID.uuidString)"
            ]
        )
    }

    func testErrorInterpreterReturnsFriendlyDecodeFailureMessage() {
        let error = VoiceUpdateClientError.requestFailed(
            statusCode: 422,
            code: "stt_audio_decode_failed",
            message: "ffmpeg exploded"
        )

        XCTAssertEqual(
            VoiceUpdateErrorInterpreter.message(for: error),
            "Backend could not decode this WAV file. Re-export the fixture as a standard PCM WAV file and try again."
        )
    }
}

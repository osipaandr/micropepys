import Foundation
import XCTest
@testable import MicropepysCore

final class VoiceUpdateClientTests: XCTestCase {
    func testVoiceUpdateRequestEncodesAudioMimeAndSnakeCaseKeys() throws {
        let request = VoiceUpdateRequest(
            audioData: Data([0x01, 0x02]),
            languageHint: "en",
            checklistItems: [
                VoiceUpdateChecklistItem(id: "item_1", title: "Passport", isCompleted: false)
            ]
        )

        let payload = try decodeJSON(request)

        XCTAssertEqual(payload["audio_base64"] as? String, "AQI=")
        XCTAssertEqual(payload["audio_mime"] as? String, "audio/wav")
        XCTAssertEqual(payload["language_hint"] as? String, "en")

        let checklistItems = try XCTUnwrap(payload["checklist_items"] as? [[String: Any]])
        XCTAssertEqual(checklistItems.count, 1)
        XCTAssertEqual(checklistItems[0]["id"] as? String, "item_1")
        XCTAssertEqual(checklistItems[0]["title"] as? String, "Passport")
        XCTAssertEqual(checklistItems[0]["is_completed"] as? Bool, false)
    }

    func testVoiceUpdateResponseDecodesMoveOperation() throws {
        let responseData = """
        {
          "transcript": "move it",
          "operations": [
            { "type": "move", "id": "item_1", "to_index": 2 }
          ],
          "confidence": 0.8
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(VoiceUpdateResponse.self, from: responseData)

        XCTAssertEqual(response.transcript, "move it")
        XCTAssertEqual(response.confidence, 0.8)
        XCTAssertEqual(response.operations, [.move(id: "item_1", toIndex: 2)])
    }

    private func decodeJSON(_ request: VoiceUpdateRequest) throws -> [String: Any] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

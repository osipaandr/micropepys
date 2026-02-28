# Micropepys Plan

## Vision
Create an easy macOS task-management tool that stays available on top of other apps and can be controlled by voice.

## Product Direction
- Keep the to-do list persistent and low-friction.
- Minimize manual editing.
- Enable natural-language updates through a global hotkey workflow.
- Stay macOS-only until the core experience is stable.
- Eventually support all UN official languages (Arabic, Chinese, English, French, Russian, Spanish).

## Current Reality
- Overlay to-do list exists.
- Manual checklist editing exists in frontend.
- Transactional checklist batch apply exists in `MicropepysCore` with undo support.
- Core undo behavior is covered by unit tests.
- Frontend has no `/voice-update` network path yet.
- Backend service is not implemented in this workspace snapshot.

## Next Milestones
1. Align shared backend/frontend contract docs to one operation schema and one supported operation set.
2. Implement backend scaffold (TypeScript + Bun), request validation, and `POST /voice-update`.
3. Implement backend STT + intent mapping to strict ordered operations with `confidence` and `needs_confirmation`.
4. Implement frontend voice flow + `/voice-update` client + wire-decoding to typed operations.
5. Implement confirmation UI and fail-safe no-op behavior for low-confidence or ambiguous operations.
6. Add multilingual voice and intent support for UN official languages.

## Core Use Case
Initial list:
- Send a passport scan to HR chat
- Prepare a presentation for Friday
- Call the sales department

Voice update:
"I've sent a passport scan. I need to schedule a meeting with Orlando and start the laundry."

Expected outcome (or equivalent intent-preserving result):
- Prepare a presentation for Friday
- Call the sales department
- Schedule a meeting with Orlando
- Start the laundry

## Readiness Blockers (as of February 28, 2026)
- No backend implementation exists for `POST /voice-update`.
- No frontend code path sends requests to `/voice-update`.
- Frontend has no implemented handling for `transcript`, `confidence`, `needs_confirmation`, or `transaction_id`.
- `ChecklistOperation` is currently in-memory only and not modeled as a decodable API transport schema.

## Things To Worry About
- Partial-transaction behavior: current batch apply can silently skip invalid operations and still apply others.
- Frontend needs strict decoding/execution rules for backend `remove`/`move` operations.
- Testing coverage gap: no integration tests for `/voice-update` flow, confirmation gating, or end-to-end transaction safety.
- Ambiguous user phrasing can produce wrong task edits.
- macOS global hotkey, accessibility, and microphone permissions can fail or be denied.
- Voice-to-text accuracy can affect intent parsing.
- Multilingual accuracy and locale-specific phrasing can reduce intent precision.

## Contract Direction (Voice Update)
- Endpoint: `POST /voice-update`
- One backend response should represent one frontend transaction.
- Use ordered `operations` array (not grouped buckets), where each operation has explicit `type`.

Proposed response shape:
```json
{
  "transcript": "string",
  "operations": [
    { "type": "complete", "id": "task_id" },
    { "type": "add", "title": "Schedule a meeting with Orlando" },
    { "type": "edit", "id": "task_id", "title": "Updated title" },
    { "type": "remove", "id": "task_id" },
    { "type": "move", "id": "task_id", "to_index": 0 }
  ],
  "confidence": 0.92,
  "needs_confirmation": false,
  "transaction_id": "tx_..."
}
```

Notes:
- `operations` order matters and must be preserved by frontend execution.
- Frontend applies the whole array as one batch transaction.
- `undo` should rollback the whole transaction, not individual operations.

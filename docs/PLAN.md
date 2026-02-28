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
- Task updates are manual.

## Next Milestones
1. Capture voice input after global hotkey.
2. Parse user intent from natural language into task operations.
3. Apply safe checklist updates (complete, add, edit).
4. Show quick confirmation/undo UI for parsed actions.
5. Add multilingual voice and intent support for UN official languages.

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

## Risks
- Ambiguous user phrasing can produce wrong task edits.
- macOS global hotkey, accessibility, and microphone permissions can fail or be denied.
- Voice-to-text accuracy can affect intent parsing.
- Multilingual accuracy and locale-specific phrasing can reduce intent precision.

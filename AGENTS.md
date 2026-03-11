# AGENTS.md

## Scope
This file is frontend-specific guidance for the macOS app in `Micropepys/`.
Shared cross-app guidance lives in `../AGENTS.md`.

## Frontend Responsibilities
- Send voice update requests to backend (`POST /voice-update`).
- Apply returned structured operations to local checklist state.
- Respect `confidence` gating in UX.
- Preserve or use metadata to support undo behavior.

## Operation Handling Rules
- Execute only explicit operations (`complete`, `add`, `edit`, `remove`, `move`).
- Do not execute freeform model text as actions.
- If operation payload is ambiguous or missing required fields, fail safely and request confirmation.

## UX and Safety
- Show transcript and intended changes when backend returns no-op due low confidence.
- Prefer reversible mutations and clear undo paths.
- Keep user-visible behavior aligned with backend safety gating.

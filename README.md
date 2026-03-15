# Micropepys

*['maɪkrəˌpiːps]*

<img src="https://upload.wikimedia.org/wikipedia/commons/2/21/Samuel_Pepys.jpg" alt="Samuel Pepys" style="max-height:300px; height:300px; width:auto;" />

> This project's name is an homage to Samuel Pepys, who famously kept a detailed diary for many years. Like Pepys' diary, this app helps you keep your thoughts and plans out of your head and always at hand.

---

**This is a _work in progress_ (WIP) client application.**

## Project Purpose
The goal of this project is to create a tool for easy task management that is always available while working in any app.
- Keep a persistent to-do list visible as an overlay.
- Let users update that list without context-switching away from their current app.
- Use a hotkey + voice dictation flow to add, complete, and edit tasks naturally.
- Focus on macOS only for now.

## Current State
- The app provides an overlay to-do list with manual editing.
- Voice updates are wired through the app to the backend and applied as one undoable transaction.
- `Cmd+Shift+V` starts/stops a voice update recording flow.
- `Cmd+,` opens Settings, where voice language can be pinned to `🇬🇧 english` or `🇷🇺 русский`.

## Target Workflow
1. User presses a global hotkey while working in any app.
2. User dictates a natural-language update.
3. Micropepys interprets intent and updates the checklist.

Example:
- Existing list:
  - Send a passport scan to HR chat
  - Prepare a presentation for Friday
  - Call the sales department
- User says: "I've sent a passport scan. I need to schedule a meeting with Orlando and start the laundry."
- Updated list (one possible result):
  - Prepare a presentation for Friday
  - Call the sales department
  - Schedule a meeting with Orlando
  - Start the laundry

---

This project is under development. Features and UI are subject to change.

<p align="center">
  <img src="assets/logo.png" width="200" alt="Meeting Assistant Logo">
</p>

# Meeting Assistant

Meeting Assistant is a high-performance terminal application that transforms spoken conversations into structured, actionable knowledge. It combines real-time local transcription with deep AI analysis to generate professional reports, visual mind maps, and insights tailored to your specific professional role.

## Why Meeting Assistant?

Manual note-taking is a cognitive burden that distracts from active participation. Standard recording tools often result in "data graveyards" where information is captured but never utilized. Meeting Assistant solves this by:

1.  **Eliminating Cognitive Load**: Focus entirely on the conversation while the AI handles the documentation.
2.  **Role-Specific Filtering**: Different roles care about different details. A Developer needs code snippets; an Executive needs ROI. Specialized personas filter the noise.
3.  **Local-First Privacy**: Using whisper.cpp, transcription happens entirely on your machine. Your raw audio never leaves your local environment.
4.  **Instant Structure**: Converts hours of audio into a 30-second read with clear decisions and action items.

---

## Real-World Examples

### 1. The Daily Standup (Persona: PM)
Focus on identifying blockers and ensuring the timeline is on track.
```bash
# Start a session focused on deliverables and blockers
meeting_assistant -l --ui -p gemini --persona pm
```
*   **Result**: A concise list of who is doing what, what is stopping them, and updated deadlines synced to your PM dashboard.

### 2. Technical Architecture Review (Persona: Dev + Research)
Focus on capturing complex logic and fact-checking external libraries.
```bash
# Capture technical details and research mentioned libraries/APIs
meeting_assistant -l --ui -p gemini --persona dev --research
```
*   **Result**: A technical brief containing mentioned code patterns, architectural trade-offs, and grounded research on the third-party tools discussed.

### 3. Executive Strategy Session (Persona: Exec)
High-level summary for stakeholders who need the bottom line without the fluff.
```bash
# Generate a high-level ROI-focused summary
meeting_assistant -f board_meeting.wav -p gemini --persona exec
```
*   **Result**: A professional HTML report ready to be emailed, focusing on strategic outcomes, budget impacts, and key decisions.

---

## Core Capabilities

### Active Intelligence
*   **Live AI Copilot**: Press [Space] during a meeting to query the AI about the current context. Useful for catching up if you joined late or missed a detail.
*   **Contextual Continuity**: Whisper retains a rolling memory of the last 200 characters, ensuring that names and technical terms mentioned earlier remain accurate throughout the session.
*   **Visual Mapping**: Every meeting generates a Mermaid.js diagram. This transforms linear speech into a non-linear knowledge graph, making it easier to see how decisions relate to one another.

### Seamless Integration
*   **Obsidian v3**: Beyond simple text, notes use modern Obsidian Properties and semantic callouts. Your meetings become an integrated part of your second brain, not just a static file.
*   **Standalone HTML**: Generates tidy, CSS-styled reports. These are perfect for teams that don't use Obsidian, allowing you to share high-quality summaries via email or Slack.

---

## Installation

### Prerequisites
*   **CMake**: 3.14 or higher.
*   **PortAudio**: Required for live microphone input (`brew install portaudio` on macOS).
*   **Whisper Model**: Download a `ggml` model (e.g., `base.en`) from HuggingFace and place it in the `models/` directory.

### Build
```bash
mkdir build && cd build
cmake -DCMAKE_PREFIX_PATH=/opt/homebrew ..
make
sudo make install
```

## Dashboard Hotkeys
*   **[Space]**: Open AI Copilot to ask a question during the meeting.
*   **[N]**: Finalize current session and start a New Meeting immediately.
*   **[Q / ESC]**: Save all reports and Quit.

## Configuration
Settings are persisted in `~/.meeting_assistant/config.json`. Update your default vault path or API keys using the `--save-config` flag.

## License
MIT

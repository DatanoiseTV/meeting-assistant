<p align="center">
  <img src="assets/logo.png" width="200" alt="Meeting Assistant Logo">
</p>

# Meeting Assistant

Meeting Assistant is a high-performance terminal application that transforms spoken conversations into structured knowledge. It combines real-time transcription with deep AI analysis to generate professional reports, visual mind maps, and actionable insights tailored to your specific professional role.

## Primary Workflow

1.  **Capture**: Initialize a live microphone session or process an existing WAV file.
2.  **Analysis**: AI automatically extracts participants, key decisions, and action items using specialized role-based personas.
3.  **Deliver**: High-quality reports are instantly generated in Markdown (for Obsidian) and standalone HTML (for sharing).

## Core Capabilities

### Real-Time Dashboard & Intelligence
*   **Interactive TUI**: A modern terminal interface with live audio metering, a blinking recording indicator, and auto-scrolling transcripts.
*   **Live AI Copilot**: Press [Space] during any meeting to ask the AI questions about the conversation so far (e.g., "What was the deadline just mentioned?").
*   **Intelligent VAD**: Energy-based Voice Activity Detection ensures audio is processed in natural sentence blocks based on silence.
*   **Continuous Sessions**: Press [N] to finalize one meeting and immediately start another without restarting the application.

### Specialized AI Analysis
*   **Role-Based Personas**: Tailor summaries with `--persona [dev|pm|exec]`.
    *   **Dev**: Technical depth, architecture decisions, and code snippets.
    *   **PM**: Deliverables, blockers, timelines, and accountability.
    *   **Exec**: ROI, high-level strategic impact, and critical outcomes.
*   **Web Grounding**: When using Gemini, enable `--research` for real-time web research on technical terms or companies mentioned.
*   **Visual Mapping**: Automatic generation of Mermaid.js diagrams visualizing the relationships between topics and decisions.

### Professional Output
*   **Standalone HTML**: Tidy, beautifully styled, single-file HTML reports perfect for email distribution.
*   **Deep Obsidian Support**: Generates notes with standard Properties, semantic callouts, and collapsible raw transcripts.
*   **Auto-Email Drafts**: Creates a ready-to-send follow-up email text file for every session.

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

---

## Usage

### Examples
```bash
# Start a live session with the TUI and Project Manager persona
meeting_assistant -l --ui -p gemini -k YOUR_API_KEY --persona pm

# Process a technical recording with web research enabled
meeting_assistant -f technical_sync.wav -p gemini -k KEY --persona dev --research

# Save defaults (e.g., Obsidian vault path and API key)
meeting_assistant --mode obsidian --obsidian-vault-path ~/MyVault -p gemini -k KEY --save-config
```

### Dashboard Hotkeys
*   **[Space]**: Open AI Copilot to ask a question during the meeting.
*   **[N]**: Finalize current session and start a New Meeting.
*   **[Q / ESC]**: Save all reports and Quit the application.

## Configuration
Settings are persisted in `~/.meeting_assistant/config.json`. This includes API keys, preferred models, and default output paths. Use the `--save-config` flag to update these via the command line.

## License
MIT

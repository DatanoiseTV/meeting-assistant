# Meeting Assistant

A high-performance C++ terminal application for real-time audio transcription and intelligent LLM-powered meeting analysis, featuring a modern TUI dashboard and advanced Obsidian integration.

## Features

*   **Interactive TUI Dashboard:** A professional terminal interface powered by `FTXUI` featuring:
    *   **Live Waveform Meter:** Real-time RMS energy gauge for microphone monitoring.
    *   **Blinking Record Indicator:** Visual red "recording" icon (●).
    *   **Auto-Scrolling Transcript:** Live view of the conversation as it happens.
    *   **Keyboard Control:** Hotkeys for ending meetings (`[Q]`) or starting new sessions (`[N]`).
*   **AI Personas:** Tailor your summary to your role with `--persona`.
    *   `dev`: Focuses on architecture, code snippets, and technical debt.
    *   `pm`: Focuses on deliverables, deadlines, and blockers.
    *   `exec`: High-level ROI, strategic impact, and strategic overview.
*   **Deep Obsidian Integration:**
    *   **Modern Properties:** Uses standard Obsidian YAML properties for date, topic, and participants.
    *   **Semantic Callouts:** Uses `[!ABSTRACT]` for summaries and `[!IMPORTANT]` for key takeaways.
    *   **Visual Mind Maps:** Automatically generates a **Mermaid.js** graph visualizing topics and decisions.
    *   **Questions Arisen:** A dedicated section capturing unresolved questions or uncertainties.
    *   **Dataview Ready:** Includes a `Status:: #processed` field for automated workflows.
*   **Intelligent Audio Engine:**
    *   **Voice Activity Detection (VAD):** Processes audio in natural sentence chunks based on silence detection.
    *   **Context-Aware Transcription:** Whisper uses the last ~200 characters of conversation context to maintain accuracy.
    *   **Robust WAV Support:** Supports arbitrary sample rates, bit depths, and multi-channel downmixing.
*   **Persistent Configuration:** Saves settings to `~/.meeting_assistant/config.json`.

## Getting Started

### Prerequisites

*   **CMake:** 3.14+
*   **PortAudio:** `brew install portaudio` (macOS)
*   **Whisper Model:** Download a `ggml` model from HuggingFace.

### Build & Install

```bash
mkdir build && cd build
cmake -DCMAKE_PREFIX_PATH=/opt/homebrew ..
make
sudo make install
```

## Usage

```bash
# Start live dashboard with Dev persona
meeting_assistant -l --ui --persona dev

# Transcribe a file using Gemini
meeting_assistant -f meeting.wav -p gemini -k YOUR_KEY

# Save defaults (e.g., your Obsidian vault path)
meeting_assistant --mode obsidian --obsidian-vault-path ~/MyVault --save-config
```

### Keyboard Shortcuts (UI Mode)
*   `[N]`: Finish current meeting, save everything, and start a **New Meeting**.
*   `[Q / ESC]`: End meeting, save everything, and **Quit**.

## License
MIT

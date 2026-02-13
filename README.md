# Meeting Assistant Pro

A high-performance C++ terminal application for real-time audio transcription and LLM-powered meeting summarization, featuring a modern TUI dashboard and deep Obsidian integration.

## Features

*   **Interactive TUI Dashboard:** A modern terminal interface powered by `FTXUI` featuring:
    *   **Live Waveform Meter:** Real-time RMS energy gauge for microphone monitoring.
    *   **Blinking Record Indicator:** Visual red "recording" icon (●).
    *   **Auto-Scrolling Transcript:** Live view of the conversation as it happens.
    *   **Keyboard Control:** Hotkeys for ending meetings or starting new sessions.
*   **Continuous Meeting Workflow:** Start a new meeting instantly with `[N]` without restarting the application. Summaries are automatically generated and saved between sessions.
*   **Intelligent Audio Processing:**
    *   **Voice Activity Detection (VAD):** Processes audio in natural sentence chunks based on silence detection.
    *   **Context-Aware Transcription:** Whisper uses the last ~200 characters of conversation context to maintain accuracy and sentence flow.
    *   **Robust WAV Support:** Supports arbitrary sample rates, bit depths, and multi-channel downmixing.
*   **LLM-Powered Summarization:**
    *   **Multi-Provider:** Supports Ollama (local), Gemini, and OpenAI.
    *   **Obsidian Mode:** Generates highly structured Markdown notes with YAML frontmatter, callouts, wikilinks, and dedicated sections for Agenda, Decisions, and Action Items.
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
# Start live dashboard (Recommended)
meeting_assistant -l --ui

# Transcribe a file using Gemini
meeting_assistant -f meeting.wav -p gemini -k YOUR_KEY

# Save defaults
meeting_assistant --mode obsidian --obsidian-vault-path ~/MyVault -p ollama --save-config
```

### Keyboard Shortcuts (UI Mode)
*   `[N]`: Finish current meeting, save summary, and start a **New Meeting**.
*   `[Q / ESC]`: End meeting, save summary, and **Quit**.

## License
MIT

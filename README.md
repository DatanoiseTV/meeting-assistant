<p align="center">
  <img src="assets/logo.png" width="200" alt="Meeting Assistant Logo">
</p>

# Meeting Assistant

A high-performance C++ terminal application for real-time audio transcription and intelligent AI-powered analysis. It transforms your meetings into structured knowledge bases with Obsidian support and professional, shareable HTML reports.

## Features

*   **Amazing HTML Reports:** Generates a standalone, beautifully styled, all-in-one HTML report for every meeting—perfect for sharing via email or browser.
*   **Interactive TUI Dashboard:** A professional terminal interface powered by FTXUI featuring:
    *   **Live Waveform Meter:** Real-time RMS energy gauge for microphone monitoring.
    *   **Blinking Record Indicator:** Visual red "recording" icon (●).
    *   **Real-time Progress:** Visual progress bar and ETA during transcription.
    *   **Keyboard Control:** Hotkeys for ending meetings ([Q]) or starting new sessions ([N]).
*   **AI Personas:** Tailor your summary to your role with --persona:
    *   dev: Focuses on architecture, code snippets, and technical debt.
    *   pm: Focuses on deliverables, deadlines, and blockers.
    *   exec: Strategic overview, ROI, and high-level outcomes.
*   **Grounding & Web Research:** Use --research (Gemini only) to perform real-time Google Search grounding on technical terms and concepts mentioned in the meeting.
*   **Deep Obsidian Integration:**
    *   **Modern Properties:** Uses standard YAML properties.
    *   **Semantic Callouts:** Uses [!ABSTRACT], [!IMPORTANT], and [!INFO] for clear categorization.
    *   **Visual Mind Maps:** Automatically generates a Mermaid.js graph.
*   **Intelligent Audio Engine:**
    *   **Voice Activity Detection (VAD):** Processes audio based on natural silence detection.
    *   **Context-Aware Transcription:** Whisper uses previous context to maintain high accuracy.
    *   **Robust WAV Support:** Auto-downmixing and resampling for any WAV file format.

## Getting Started

### Prerequisites

*   **CMake:** 3.14+
*   **PortAudio:** brew install portaudio (macOS)
*   **Whisper Model:** Download a ggml model (e.g., base.en) from HuggingFace.

### Build & Install

```bash
mkdir build && cd build
cmake -DCMAKE_PREFIX_PATH=/opt/homebrew ..
make
sudo make install
```

## Usage

The application automatically generates Markdown, HTML, and Email Drafts for every session.

```bash
# Start live dashboard with Gemini Research and Dev persona
meeting_assistant -l --ui -p gemini -k YOUR_API_KEY --research --persona dev

# Transcribe a file as a Project Manager
meeting_assistant -f meeting.wav -p gemini -k KEY --persona pm

# Save your API key and Obsidian path as default
meeting_assistant --mode obsidian --obsidian-vault-path ~/MyVault -p gemini -k KEY --save-config
```

### Keyboard Shortcuts (UI Mode)
*   [N]: Finish current meeting and start a New Meeting immediately.
*   [Q / ESC]: End meeting, generate all reports, and Quit.

## Configuration

Settings are persisted in ~/.meeting_assistant/config.json. You can edit this file manually or use the --save-config flag to update it.

## License
MIT

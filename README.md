<p align="center">
  <img src="assets/logo.png" width="160" alt="Meeting Assistant Logo">
</p>

# Meeting Assistant

Meeting Assistant is a high-performance C++ tool built to turn spoken conversations into structured, actionable knowledge. It combines real-time local transcription with deep AI analysis to generate professional reports, visual mind maps, and synchronized tasks tailored to your specific role.

## Why this exists

Note-taking is a cognitive tax that prevents you from actually being present in a meeting. Most existing solutions are "data graveyards" or privacy nightmares that send your raw audio to the cloud.

Meeting Assistant is built for a different workflow:
*   **Privacy First**: Powered by `whisper.cpp`, transcription happens 100% offline. Your raw audio never leaves your disk.
*   **High Performance**: Minimal footprint, written in C++17 for zero-latency feedback and stable long-running sessions.
*   **Truly Actionable**: It doesn't just summarize; it creates GitHub issues, Obsidian notes, and executive-grade HTML reports automatically.
*   **Zero-Bot Friction**: No intrusive bots joining your calls. It captures your system audio or microphone silently and locally.

---

## Core Capabilities

### Active Intelligence
*   **Live AI Copilot**: Press `[Space]` during a meeting to query the context in real-time. Clarify a technical term or catch up on what you missed without interrupting the flow.
*   **Contextual Continuity**: Whisper retains a rolling memory of the last 200 characters, ensuring technical terms and names remain accurate across long sessions.
*   **Visual Knowledge Graphs**: Every meeting generates a Mermaid.js diagram, visualizing the relationships between topics, people, and decisions.

### Specialized Analysis (Personas)
Tailor the output to the audience using `--persona`:
*   **Dev**: Focuses on architecture, technical trade-offs, code patterns, and technical debt.
*   **PM**: Focuses on deliverables, blockers, timelines, and accountability.
*   **Exec**: Focuses on high-level strategic impact, budget, and ROI.

### Deep Integration
*   **Obsidian v3**: Generates notes with standard YAML Properties, semantic callouts (e.g., `[!ABSTRACT]`), and collapsible transcripts.
*   **Issue Tracker Sync**: Automatically parses Action Items and creates tickets on **GitHub** or **GitLab**.
*   **Corporate HTML**: Tidy, emoji-free reports styled with **Plus Jakarta Sans** and **Inter**. Includes a sticky sidebar and hidden transcripts for executive review.

---

## Installation

### 1. Prerequisites
*   **CMake**: 3.14 or higher.
*   **PortAudio**: Required for live microphone input (`brew install portaudio` on macOS).

### 2. Download a Whisper Model
Choose a `ggml` model based on your hardware. You can download them directly:

| Model | Size | Speed | Accuracy | Recommended For |
| :--- | :--- | :--- | :--- | :--- |
| [**tiny.en**](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin) | 75 MB | Fastest | Lowest | Low-power devices |
| [**base.en**](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin) | 142 MB | Very Fast | Good | Standard laptops |
| [**small.en**](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin) | 466 MB | Fast | Great | High-accuracy needs |
| [**medium.en**](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin) | 1.5 GB | Slow | Excellent | Batch processing |
| [**large-v3**](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin) | 2.9 GB | Slowest | SOTA | Max precision (GPU) |

**Quick download example:**
```bash
mkdir -p models
curl -L https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin -o models/ggml-base.en.bin
```

### 3. Build
```bash
mkdir build && cd build
cmake -DCMAKE_PREFIX_PATH=/opt/homebrew ..
make -j$(nproc)
sudo make install
```

---

## Usage & Workflows

### Examples
```bash
# Start a live session with the TUI and PM persona
meeting_assistant -l --ui -p gemini --persona pm

# Process a technical WAV file with web research enabled
meeting_assistant -f technical_sync.wav -p gemini --persona dev --research

# 100% Offline Workflow (Local Transcription + Local LLM)
meeting_assistant -l --ui -p ollama -L llama3

# Run as a native macOS Tray Application
meeting_assistant --tray
```

### Dashboard Hotkeys
*   **[Space]**: Open AI Copilot modal for real-time questions.
*   **[N]**: Finalize current meeting and start a new session immediately.
*   **[Q / ESC]**: Save all reports and Quit.

---

## Configuration

Settings are persisted in `~/.meeting_assistant/config.json`. 

1.  Copy the provided `config.json.example` to `~/.meeting_assistant/config.json`.
2.  Populate your API keys (Gemini, OpenAI, or Ollama) and integration tokens (GitHub/GitLab).
3.  Alternatively, use the `--save-config` flag to persist your current CLI flags as defaults.

## Tech Stack
*   **C++17**: Performance and concurrency.
*   **whisper.cpp**: Local, state-of-the-art STT.
*   **FTXUI**: Modern animated terminal interface.
*   **PortAudio**: Cross-platform audio capture.
*   **libcurl**: Robust LLM API communication with exponential backoff.

## License
Apache License 2.0 - See `LICENSE` for details. Requires attribution.

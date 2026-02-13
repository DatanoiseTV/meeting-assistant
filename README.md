# Meeting Assistant

A C++ command-line application for transcribing audio and generating LLM-powered summaries, with specialized output for Obsidian.

## Features

*   **Audio Transcription:** Transcribes audio from:
    *   Live microphone input (using PortAudio).
    *   WAV files (supports various sample rates, bit depths, and channel counts, automatically converting to 16kHz mono float for Whisper.cpp).
*   **Speech Recognition:** Utilizes `ggerganov/whisper.cpp` for high-performance, local speech-to-text transcription.
*   **Speaker Turn Detection:** Attempts to identify speaker changes in the transcription, labeling segments as "Speaker 1" and "Speaker 2" (note: this is *not* speaker recognition by identity, but rather turn detection).
*   **LLM-Powered Summarization:** Generates structured meeting summaries using various Large Language Model APIs:
    *   Ollama (for local models like Llama3).
    *   Gemini API.
    *   OpenAI compatible APIs.
*   **Obsidian Integration:** A dedicated `--mode obsidian` to generate highly structured Markdown notes tailored for Obsidian, featuring:
    *   Dynamically generated YAML frontmatter (with date, time, title, participants, tags, and a brief summary).
    *   Obsidian Callouts for meeting overview.
    *   Structured sections for Key Discussion Points, Decisions Made, and Action Items.
    *   Extensive use of `[[wikilinks]]` and `#tags` for enhanced graph view and navigability within Obsidian.
*   **Customizable Filenames:** Obsidian notes are named based on an LLM-generated title and the current date for easy organization.
*   **Graceful Shutdown:** Handles `Ctrl+C` for proper saving of in-progress transcriptions and summaries.

## Getting Started

### Prerequisites

*   **CMake:** Version 3.14 or higher.
*   **C++ Compiler:** C++17 compatible.
*   **PortAudio:** Required for live audio input.
    *   **macOS (Homebrew):** `brew install portaudio`
*   **Git:** For cloning the repository.

### Build Instructions

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/DatanoiseTV/meeting-assistant.git
    cd meeting-assistant
    ```

2.  **Configure and build with CMake:**
    ```bash
    mkdir build
    cd build
    # For macOS with Homebrew PortAudio:
    cmake -DCMAKE_PREFIX_PATH=/opt/homebrew ..
    make
    ```

### Download Whisper Model

```bash
mkdir -p models
curl -L https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin -o models/ggml-base.en.bin
```

## Usage

```bash
./build/meeting_assistant [OPTIONS]
```

*   `-f <input.wav>`: Input WAV file for transcription.
*   `-l`: Enable live audio transcription.
*   `-p <provider>`: LLM Provider (`ollama`, `gemini`, `openai`).
*   `-k <api_key>`: API Key for LLM provider (or base URL for Ollama).
*   `-L <llm_model>`: Specific model name.
*   `--mode obsidian`: Generate Obsidian-friendly notes.
*   `--obsidian-vault-path <path>`: Path to your Obsidian vault.

## License

MIT

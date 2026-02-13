# Meeting Assistant

A C++ command-line application for transcribing audio and generating LLM-powered summaries, with specialized output for Obsidian.

## Features

*   **Audio Transcription:** Transcribes audio from:
    *   Live microphone input (using PortAudio).
    *   WAV files (supports various sample rates, bit depths, and channel counts, automatically converting to 16kHz mono float for Whisper.cpp).
*   **Voice Activity Detection (VAD):** In live mode, the assistant intelligently detects pauses in speech (silence) to process audio in natural chunks, rather than fixed time intervals.
*   **Persistent Configuration:** Saves your settings (API keys, paths, models) to `~/.meeting_assistant/config.json`, so you don't have to type them every time.
*   **Speech Recognition:** Utilizes `ggerganov/whisper.cpp` for high-performance, local speech-to-text transcription.
*   **Speaker Turn Detection:** Attempts to identify speaker changes in the transcription.
*   **LLM-Powered Summarization:** Generates structured meeting summaries using various Large Language Model APIs:
    *   Ollama (for local models like Llama3).
    *   Gemini API.
    *   OpenAI compatible APIs.
*   **Obsidian Integration:** A dedicated `--mode obsidian` to generate highly structured Markdown notes tailored for Obsidian, featuring:
    *   Dynamically generated YAML frontmatter.
    *   Obsidian Callouts for meeting overview.
    *   Structured sections for Key Discussion Points, Decisions Made, and Action Items.
    *   Extensive use of `[[wikilinks]]` and `#tags`.
*   **Customizable Filenames:** Obsidian notes are named based on an LLM-generated title and the current date.
*   **Graceful Shutdown:** Handles `Ctrl+C` for proper saving of in-progress transcriptions and summaries.

## Getting Started

### Prerequisites

*   **CMake:** Version 3.14 or higher.
*   **C++ Compiler:** C++17 compatible.
*   **PortAudio:** Required for live audio input.
    *   **macOS (Homebrew):** `brew install portaudio`
*   **Git:** For cloning the repository.

### Build & Install

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/DatanoiseTV/meeting-assistant.git
    cd meeting-assistant
    ```

2.  **Configure and build:**
    ```bash
    mkdir build
    cd build
    cmake -DCMAKE_PREFIX_PATH=/opt/homebrew .. # Adjust for your PortAudio path
    make
    ```

3.  **Install (Optional):**
    ```bash
    sudo make install
    ```

### Download Whisper Model

```bash
mkdir -p models
curl -L https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin -o models/ggml-base.en.bin
```

## Configuration

The application uses a configuration file located at `~/.meeting_assistant/config.json`.
You can set your defaults here so you don't have to pass arguments every time.

To save your current command-line arguments as the default configuration:
```bash
./build/meeting_assistant --mode obsidian --obsidian-vault-path /path/to/vault -p ollama -L llama3 --save-config
```

Example `config.json`:
```json
{
    "api_key": "",
    "llm_model": "llama3",
    "mode": "obsidian",
    "model_path": "models/ggml-base.en.bin",
    "obsidian_vault_path": "/Users/you/Documents/Obsidian/Vault",
    "output_dir": "output",
    "provider": "ollama",
    "vad_silence_ms": 1000,
    "vad_threshold": 0.01
}
```

## Usage

```bash
meeting_assistant [OPTIONS]
```

*   `-f <input.wav>`: Input WAV file.
*   `-l`: Enable live audio transcription.
*   `--save-config`: Save provided arguments to the config file and exit.
*   `--vad-threshold <float>`: RMS energy threshold for silence (default 0.01).

(See `README.md` source for full options list).

## License

MIT

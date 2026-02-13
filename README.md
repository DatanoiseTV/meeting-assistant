<p align="center">
  <img src="assets/logo.png" width="200" alt="Meeting Assistant Logo">
</p>

# Meeting Assistant

Meeting Assistant transforms your spoken conversations into structured, actionable knowledge. It handles real-time transcription, deep AI analysis, and generates professional reports tailored for your specific role.

## The Workflow

1. **Speak**: Start a live session or drop in a WAV file.
2. **Analyze**: AI identifies participants, decisions, and action items using specialized personas.
3. **Integrate**: Results are instantly synced to your Obsidian vault and formatted as a standalone HTML report.

## Key Outcomes

### Structured Obsidian Notes
Every meeting becomes a permanent node in your knowledge base. Notes include dynamic YAML properties, semantic callouts for summaries, and automated wikilinks.

### Visual Knowledge Graphs
The AI automatically generates Mermaid.js diagrams to visualize the relationships between discussed topics, people, and decisions.

### Professional HTML Reports
Generate tidy, standalone HTML reports styled for corporate environments. Perfect for immediate distribution via email to stakeholders.

### Fact-Checked Research
When using Gemini, the assistant performs real-time web grounding to provide additional context and fact-check technical terms or companies mentioned in the meeting.

### Role-Specific Intelligence
Tailor the analysis by choosing a persona:
* **Dev**: Focuses on architecture, code, and technical debt.
* **PM**: Focuses on deliverables, deadlines, and blockers.
* **Exec**: Focuses on high-level ROI and strategic impact.

---

## Quick Start

### Build

```bash
mkdir build && cd build
cmake -DCMAKE_PREFIX_PATH=/opt/homebrew ..
make
sudo make install
```

### Usage

```bash
# Start a live dashboard session
meeting_assistant -l --ui -p gemini -k YOUR_API_KEY --research

# Analyze a recorded file as a Project Manager
meeting_assistant -f sync.wav -p gemini -k YOUR_API_KEY --persona pm
```

### Dashboard Hotkeys
* **[N]**: Start a new meeting immediately.
* **[Q]**: Save all reports and quit.

---

## Advanced Capabilities

* **Intelligent VAD**: High-accuracy silence detection ensures transcription happens in natural sentence blocks.
* **Contextual Memory**: Whisper retains the last 200 characters of context to maintain accuracy across ongoing sentences.
* **Format Agnostic**: Support for arbitrary WAV sample rates and bit depths with automatic mono-conversion.
* **Persistent Settings**: Configure your vault path and API keys once in `~/.meeting_assistant/config.json`.

## License
MIT

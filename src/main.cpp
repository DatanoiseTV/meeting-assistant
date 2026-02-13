#include <iostream>
#include <string>
#include <vector>
#include <fstream>
#include <filesystem>
#include <sstream>
#include <chrono>
#include <thread>
#include <csignal>
#include <algorithm>
#include <cctype>
#include <iomanip>
#include <cstring>
#include <cmath>

#include "Transcriber.h"
#include "LLMClients.h"
#include "AudioCapture.h"
#include "Config.h"

namespace fs = std::filesystem;
volatile sig_atomic_t shutdown_requested = 0;
void signal_handler(int s) { if (s == SIGINT) shutdown_requested = 1; }

void trim(std::string& s) {
    s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](unsigned char ch) { return !std::isspace(ch); }));
    s.erase(std::find_if(s.rbegin(), s.rend(), [](unsigned char ch) { return !std::isspace(ch); }).base(), s.end());
}

float calculate_rms(const std::vector<float>& samples) {
    if (samples.empty()) return 0.0f;
    float sum_sq = 0.0f;
    for (float s : samples) sum_sq += s * s;
    return std::sqrt(sum_sq / samples.size());
}

void print_usage(const char* prog) {
    std::cout << "Meeting Assistant - Audio Transcription & LLM Summarization\n\n";
    std::cout << "Usage: " << prog << " [-f <input.wav> | -l] [options]\n\n";
    std::cout << "Core Options:\n";
    std::cout << "  -f <path>              Path to input WAV file for transcription.\n";
    std::cout << "  -l                     Enable live audio transcription from default microphone.\n";
    std::cout << "  -m <path>              Path to Whisper model (default: models/ggml-base.en.bin).\n";
    std::cout << "  -o <path>              Output directory for transcripts/summaries (default: output).\n\n";
    std::cout << "LLM Summarization Options:\n";
    std::cout << "  -p <provider>          LLM Provider: 'ollama', 'gemini', or 'openai'.\n";
    std::cout << "  -k <api_key>           API Key for the provider (or base URL for Ollama).\n";
    std::cout << "  -L <model_name>        Specific LLM model to use (e.g., 'llama3', 'gemini-pro').\n";
    std::cout << "  --mode <mode>          Output mode: 'standard' (Markdown) or 'obsidian' (Structured).\n";
    std::cout << "  --obsidian-vault-path <p> Path to your Obsidian vault (required for obsidian mode).\n\n";
    std::cout << "Configuration & Advanced:\n";
    std::cout << "  --save-config          Save all provided arguments to ~/.meeting_assistant/config.json and exit.\n";
    std::cout << "  --vad-threshold <f>    RMS energy threshold for silence detection (default: 0.01).\n";
    std::cout << "  --help, -h             Show this help message.\n\n";
    std::cout << "Examples:\n";
    std::cout << "  1. Live transcription with Obsidian notes (Ollama):\n";
    std::cout << "     " << prog << " -l --mode obsidian --obsidian-vault-path ~/MyNotes -p ollama\n\n";
    std::cout << "  2. Transcribe a file using Gemini API:\n";
    std::cout << "     " << prog << " -f meeting.wav -p gemini -k YOUR_API_KEY\n\n";
    std::cout << "  3. Save default settings for future runs:\n";
    std::cout << "     " << prog << " -p openai -k YOUR_KEY -L gpt-4 --mode obsidian --save-config\n";
}

int main(int argc, char** argv) {
    std::signal(SIGINT, signal_handler);
    Config::Data config = Config::load();
    std::string wavPath;
    bool liveAudio = false;
    bool saveConfig = false;

    if (argc < 2) { print_usage(argv[0]); return 0; }

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-f" && i + 1 < argc) wavPath = argv[++i];
        else if (arg == "-l") liveAudio = true;
        else if (arg == "-m" && i + 1 < argc) config.model_path = argv[++i];
        else if (arg == "-p" && i + 1 < argc) config.provider = argv[++i];
        else if (arg == "-k" && i + 1 < argc) config.api_key = argv[++i];
        else if (arg == "-L" && i + 1 < argc) config.llm_model = argv[++i];
        else if (arg == "-o" && i + 1 < argc) config.output_dir = argv[++i];
        else if (arg == "--mode" && i + 1 < argc) config.mode = argv[++i];
        else if (arg == "--obsidian-vault-path" && i + 1 < argc) config.obsidian_vault_path = argv[++i];
        else if (arg == "--vad-threshold" && i + 1 < argc) config.vad_threshold = std::stof(argv[++i]);
        else if (arg == "--save-config") saveConfig = true;
        else if (arg == "--help" || arg == "-h") { print_usage(argv[0]); return 0; }
    }

    if (saveConfig) { Config::save(config); return 0; }
    if (wavPath.empty() && !liveAudio) { print_usage(argv[0]); return 1; }
    if (config.mode == "obsidian" && config.obsidian_vault_path.empty()) { std::cerr << "Error: --obsidian-vault-path required.\n"; return 1; }

    std::cout << "Loading Whisper model: " << config.model_path << std::endl;
    Transcriber transcriber(config.model_path);
    std::vector<float> pcmf32_data; std::stringstream current_transcription_text; std::string baseName;

    if (liveAudio) {
        AudioCapture audioCapture; if (!audioCapture.startCapture()) return 1;
        std::cout << "Live transcription active. Pauses trigger processing. Ctrl+C to finish.\n";
        float silence_ms = 0; const int chunk_ms = 100; const int chunk_samples = SAMPLE_RATE * chunk_ms / 1000;
        while (!shutdown_requested) {
            std::vector<float> chunk;
            if (audioCapture.getAudioChunk(chunk, chunk_samples)) {
                pcmf32_data.insert(pcmf32_data.end(), chunk.begin(), chunk.end());
                if (calculate_rms(chunk) < config.vad_threshold) silence_ms += chunk_ms; else silence_ms = 0;
                float buffer_sec = pcmf32_data.size() / (float)SAMPLE_RATE;
                if ((silence_ms >= config.vad_silence_ms && buffer_sec > 2.0f) || buffer_sec >= 30.0f || (shutdown_requested && !pcmf32_data.empty())) {
                    if (buffer_sec > 0.5f) {
                        auto segments = transcriber.transcribe(pcmf32_data); pcmf32_data.clear(); silence_ms = 0;
                        for (const auto& seg : segments) {
                            int t0 = seg.t0 / 100; char buf[64]; snprintf(buf, sizeof(buf), "[%02d:%02d]", t0 / 60, t0 % 60);
                            std::cout << buf << ": " << seg.text << std::endl;
                            current_transcription_text << buf << ": " << seg.text << "\n";
                        }
                    } else pcmf32_data.clear();
                }
            } else std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        audioCapture.stopCapture();
        auto now = std::chrono::system_clock::now(); auto in_time_t = std::chrono::system_clock::to_time_t(now);
        std::stringstream ss; ss << std::put_time(std::localtime(&in_time_t), "%Y%m%d_%H%M%S"); baseName = "meeting_" + ss.str();
    } else {
        std::ifstream file(wavPath, std::ios::binary); if (!file.is_open()) return 1;
        char buf[4]; file.read(buf, 4); file.ignore(4); file.read(buf, 4);
        uint16_t audioFormat = 0, numChannels = 0, bitsPerSample = 0; uint32_t sampleRate = 0, dataSize = 0;
        while (file.read(buf, 4)) {
            std::string id(buf, 4); uint32_t size; file.read(reinterpret_cast<char*>(&size), 4);
            if (id == "fmt ") { file.read(reinterpret_cast<char*>(&audioFormat), 2); file.read(reinterpret_cast<char*>(&numChannels), 2); file.read(reinterpret_cast<char*>(&sampleRate), 4); file.ignore(6); file.read(reinterpret_cast<char*>(&bitsPerSample), 2); file.ignore(size - 16); }
            else if (id == "data") { dataSize = size; break; } else file.ignore(size);
        }
        std::vector<char> raw(dataSize); file.read(raw.data(), dataSize); file.close();
        std::vector<float> pcm_raw; size_t n_s = dataSize / (std::max((int)numChannels, 1) * std::max((int)bitsPerSample / 8, 1));
        for (size_t i = 0; i < n_s; ++i) {
            float s = 0; for (int c = 0; c < numChannels; ++c) {
                size_t o = (i * numChannels + c) * (bitsPerSample / 8);
                if (bitsPerSample == 16) { int16_t v; std::memcpy(&v, raw.data() + o, 2); s += v / 32768.0f; }
                else if (bitsPerSample == 32 && audioFormat == 3) { float v; std::memcpy(&v, raw.data() + o, 4); s += v; }
            }
            pcm_raw.push_back(s / std::max((int)numChannels, 1));
        }
        if (sampleRate != 16000) {
            double r = 16000.0 / sampleRate; size_t n_new = pcm_raw.size() * r;
            for (size_t i = 0; i < n_new; ++i) {
                double idx = i / r; size_t x1 = (size_t)idx, x2 = x1 + 1;
                if (x2 >= pcm_raw.size()) pcmf32_data.push_back(pcm_raw[x1]);
                else pcmf32_data.push_back(pcm_raw[x1] * (1.0 - (idx - x1)) + pcm_raw[x2] * (idx - x1));
            }
        } else pcmf32_data = std::move(pcm_raw);
        auto segments = transcriber.transcribe(pcmf32_data);
        for (const auto& seg : segments) {
            int t0 = seg.t0 / 100; char b[64]; snprintf(b, sizeof(b), "[%02d:%02d]", t0 / 60, t0 % 60);
            current_transcription_text << b << ": " << seg.text << "\n";
        }
        baseName = fs::path(wavPath).stem().string();
    }

    std::string transcription = current_transcription_text.str();
    if (transcription.empty()) return 0;
    std::string finalOutputDir = (config.mode == "obsidian") ? config.obsidian_vault_path : config.output_dir;
    fs::create_directories(finalOutputDir);
    std::ofstream(finalOutputDir + "/" + baseName + "_transcript.md") << transcription;

    if (!config.provider.empty()) {
        auto client = ClientFactory::createClient(config.provider, config.api_key, config.llm_model);
        if (client) {
            std::cout << "\nGenerating Summary via " << config.provider << "...\n";
            if (config.mode == "obsidian") {
                std::string title = client->generateSummary(TITLE_PROMPT + transcription); trim(title);
                std::string master = client->generateSummary(OBSIDIAN_MASTER_PROMPT + transcription);
                auto ext = [&](const std::string& c, const std::string& s, const std::string& e) {
                    size_t st = c.find(s); if (st == std::string::npos) return std::string();
                    st += s.length(); size_t en = c.find(e, st); return c.substr(st, (en == std::string::npos) ? std::string::npos : en - st);
                };
                auto tsec = [](std::string& s) {
                    s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](unsigned char ch) { return !std::isspace(ch); }));
                    s.erase(std::find_if(s.rbegin(), s.rend(), [](unsigned char ch) { return !std::isspace(ch); }).base(), s.end());
                };
                std::string p = ext(master, "---PARTICIPANTS---", "---TAGS---"); tsec(p);
                std::string t = ext(master, "---TAGS---", "---YAML_SUMMARY---"); tsec(t);
                std::string ys = ext(master, "---YAML_SUMMARY---", "---OVERVIEW_SUMMARY---"); tsec(ys);
                std::string os = ext(master, "---OVERVIEW_SUMMARY---", "---AGENDA_ITEMS---"); tsec(os);
                std::string ai = ext(master, "---AGENDA_ITEMS---", "---DISCUSSION_POINTS---"); tsec(ai);
                std::string dp = ext(master, "---DISCUSSION_POINTS---", "---DECISIONS_MADE---"); tsec(dp);
                std::string dm = ext(master, "---DECISIONS_MADE---", "---ACTION_ITEMS---"); tsec(dm);
                std::string acts = ext(master, "---ACTION_ITEMS---", "Transcription:"); tsec(acts);
                if (title.empty()) title = "Meeting " + baseName;
                std::string san = title; for (char& c : san) { if (c == ' ') c = '-'; else if (!std::isalnum(c) && c != '-') c = '_'; }
                auto now = std::chrono::system_clock::now(); auto t_now = std::chrono::system_clock::to_time_t(now);
                std::stringstream ss; ss << std::put_time(std::localtime(&t_now), "%Y-%m-%d");
                std::string fBase = san + "-" + ss.str();
                std::stringstream note;
                note << "---\ndate: " << ss.str() << "\ntitle: \"" << title << "\"\nparticipants: " << (p.empty() ? "[]" : p) << "\ntags: " << (t.empty() ? "[]" : t) << "\nsummary: " << ys << "\n---\n\n";
                note << "> [!SUMMARY] Meeting Overview\n> " << os << "\n\n## Meeting Details\n\n### Agenda\n" << (ai.empty() ? "- N/A" : ai) << "\n\n";
                note << "### Key Discussion Points\n" << (dp.empty() ? "- N/A" : dp) << "\n\n## Decisions Made\n" << (dm.empty() ? "- N/A" : dm) << "\n\n## Action Items\n" << (acts.empty() ? "- N/A" : acts) << "\n\n## Raw Transcription\n```\n" << transcription << "\n```\n";
                std::ofstream(finalOutputDir + "/" + fBase + ".md") << note.str();
                std::cout << "Obsidian note saved to: " << fBase << ".md\n";
            } else {
                std::string sum = client->generateSummary(SUMMARY_PROMPT + transcription);
                std::ofstream(finalOutputDir + "/" + baseName + "_summary.md") << "# Meeting Summary\n\n" << sum;
                std::cout << "Summary saved.\n";
            }
        }
    }
    return 0;
}

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

#include "Transcriber.h"
#include "LLMClients.h"
#include "AudioCapture.h"

namespace fs = std::filesystem;
volatile sig_atomic_t shutdown_requested = 0;
void signal_handler(int s) { if (s == SIGINT) shutdown_requested = 1; }

void trim(std::string& s) {
    s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](unsigned char ch) { return !std::isspace(ch); }));
    s.erase(std::find_if(s.rbegin(), s.rend(), [](unsigned char ch) { return !std::isspace(ch); }).base(), s.end());
}

int main(int argc, char** argv) {
    std::signal(SIGINT, signal_handler);
    std::string wavPath, modelPath = "models/ggml-base.en.bin", provider, apiKey, llmModel, outputDir = "output", mode = "standard", obsidianVaultPath;
    bool liveAudio = false;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-f" && i + 1 < argc) wavPath = argv[++i];
        else if (arg == "-l") liveAudio = true;
        else if (arg == "-m" && i + 1 < argc) modelPath = argv[++i];
        else if (arg == "-p" && i + 1 < argc) provider = argv[++i];
        else if (arg == "-k" && i + 1 < argc) apiKey = argv[++i];
        else if (arg == "-L" && i + 1 < argc) llmModel = argv[++i];
        else if (arg == "-o" && i + 1 < argc) outputDir = argv[++i];
        else if (arg == "--mode" && i + 1 < argc) mode = argv[++i];
        else if (arg == "--obsidian-vault-path" && i + 1 < argc) obsidianVaultPath = argv[++i];
    }

    if (wavPath.empty() && !liveAudio) return 1;
    Transcriber transcriber(modelPath);
    std::vector<float> pcmf32_data; std::stringstream current_transcription_text; std::string baseName;

    if (liveAudio) {
        AudioCapture audioCapture; if (!audioCapture.startCapture()) return 1;
        std::cout << "Starting live transcription. Press Ctrl+C to stop.\n";
        while (!shutdown_requested) {
            std::vector<float> chunk; if (audioCapture.getAudioChunk(chunk, SAMPLE_RATE / 2)) {
                pcmf32_data.insert(pcmf32_data.end(), chunk.begin(), chunk.end());
                if (pcmf32_data.size() >= SAMPLE_RATE * 5 || (shutdown_requested && !pcmf32_data.empty())) {
                    auto segments = transcriber.transcribe(pcmf32_data); pcmf32_data.clear();
                    for (const auto& seg : segments) {
                        int t0 = seg.t0 / 100, t1 = seg.t1 / 100; char b[64]; snprintf(b, sizeof(b), "[%02d:%02d - %02d:%02d]", t0 / 60, t0 % 60, t1 / 60, t1 % 60);
                        current_transcription_text << "Speaker 1 " << b << ": " << seg.text << "\n";
                        std::cout << "Speaker 1 " << b << ": " << seg.text << std::endl;
                    }
                }
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
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
            int t0 = seg.t0 / 100, t1 = seg.t1 / 100; char b[64]; snprintf(b, sizeof(b), "[%02d:%02d - %02d:%02d]", t0 / 60, t0 % 60, t1 / 60, t1 % 60);
            current_transcription_text << "Speaker 1 " << b << ": " << seg.text << "\n";
        }
        baseName = fs::path(wavPath).stem().string();
    }

    std::string transcription = current_transcription_text.str();
    std::string finalOutputDir = (mode == "obsidian") ? obsidianVaultPath : outputDir;
    fs::create_directories(finalOutputDir);
    std::ofstream(finalOutputDir + "/" + baseName + "_transcript.md") << transcription;

    if (!provider.empty()) {
        if (llmModel.empty()) llmModel = (provider == "ollama") ? "llama3" : (provider == "gemini") ? "gemini-pro" : "gpt-3.5-turbo";
        auto client = ClientFactory::createClient(provider, apiKey, llmModel);
        if (client) {
            if (mode == "obsidian") {
                std::string title = client->generateSummary(TITLE_PROMPT + transcription); trim(title);
                std::string master = client->generateSummary(OBSIDIAN_MASTER_PROMPT + transcription);
                auto ext = [&](const std::string& c, const std::string& s, const std::string& e) {
                    size_t st = c.find(s); if (st == std::string::npos) return std::string();
                    st += s.length(); size_t en = c.find(e, st); return c.substr(st, (en == std::string::npos) ? std::string::npos : en - st);
                };
                std::string p = ext(master, "---PARTICIPANTS---", "---TAGS---"); trim(p);
                std::string t = ext(master, "---TAGS---", "---YAML_SUMMARY---"); trim(t);
                std::string ys = ext(master, "---YAML_SUMMARY---", "---OVERVIEW_SUMMARY---"); trim(ys);
                std::string os = ext(master, "---OVERVIEW_SUMMARY---", "---AGENDA_ITEMS---"); trim(os);
                std::string ai = ext(master, "---AGENDA_ITEMS---", "---DISCUSSION_POINTS---"); trim(ai);
                std::string dp = ext(master, "---DISCUSSION_POINTS---", "---DECISIONS_MADE---"); trim(dp);
                std::string dm = ext(master, "---DECISIONS_MADE---", "---ACTION_ITEMS---"); trim(dm);
                std::string acts = ext(master, "---ACTION_ITEMS---", "Transcription:"); trim(acts);
                
                std::string san = title; for (char& c : san) { if (c == ' ') c = '-'; else if (!std::isalnum(c) && c != '-') c = '_'; }
                auto now = std::chrono::system_clock::now(); auto t_now = std::chrono::system_clock::to_time_t(now);
                std::stringstream ss; ss << std::put_time(std::localtime(&t_now), "%Y-%m-%d");
                std::string fBase = san + "-" + ss.str();
                
                std::stringstream note;
                note << "---\ndate: " << ss.str() << "\ntitle: \"" << title << "\"\nparticipants: " << (p.empty() ? "[]" : p) << "\ntags: " << (t.empty() ? "[]" : t) << "\nsummary: " << ys << "\n---\n\n";
                note << "> [!SUMMARY] Meeting Overview\n> " << os << "\n\n## Meeting Details\n\n### Agenda\n" << ai << "\n\n### Key Discussion Points\n" << dp << "\n\n## Decisions Made\n" << dm << "\n\n## Action Items\n" << acts << "\n\n## Raw Transcription\n```\n" << transcription << "\n```\n";
                std::ofstream(finalOutputDir + "/" + fBase + ".md") << note.str();
            } else {
                std::string sum = client->generateSummary(SUMMARY_PROMPT + transcription);
                std::ofstream(finalOutputDir + "/" + baseName + "_summary.md") << "# Meeting Summary\n\n" << sum;
            }
        }
    }
    return 0;
}

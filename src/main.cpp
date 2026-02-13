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
#include "TerminalUI.h"

namespace fs = std::filesystem;
volatile sig_atomic_t shutdown_requested = 0;
void signal_handler(int s) { 
    shutdown_requested = 1; 
    TerminalUI::stop();
}

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

std::string format_timestamp(int64_t t_ms) {
    int64_t total_sec = t_ms / 1000;
    int h = total_sec / 3600;
    int m = (total_sec % 3600) / 60;
    int s = total_sec % 60;
    char buf[32];
    snprintf(buf, sizeof(buf), "%02d:%02d:%02d", h, m, s);
    return std::string(buf);
}

int main(int argc, char** argv) {
    std::signal(SIGINT, signal_handler);
    Config::Data config = Config::load();
    std::string wavPath;
    bool liveAudio = false, saveConfig = false, showUI = false;

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-f" && i + 1 < argc) wavPath = argv[++i];
        else if (arg == "-l") liveAudio = true;
        else if (arg == "--ui") showUI = true;
        else if (arg == "-m" && i + 1 < argc) config.model_path = argv[++i];
        else if (arg == "-p" && i + 1 < argc) config.provider = argv[++i];
        else if (arg == "-k" && i + 1 < argc) config.api_key = argv[++i];
        else if (arg == "-L" && i + 1 < argc) config.llm_model = argv[++i];
        else if (arg == "-o" && i + 1 < argc) config.output_dir = argv[++i];
        else if (arg == "--mode" && i + 1 < argc) config.mode = argv[++i];
        else if (arg == "--obsidian-vault-path" && i + 1 < argc) config.obsidian_vault_path = argv[++i];
        else if (arg == "--vad-threshold" && i + 1 < argc) config.vad_threshold = std::stof(argv[++i]);
        else if (arg == "--save-config") saveConfig = true;
    }

    if (saveConfig) { Config::save(config); return 0; }
    if (wavPath.empty() && !liveAudio) return 1;

    Transcriber transcriber(config.model_path);
    std::vector<float> pcmf32_data; 
    
    if (liveAudio) {
        bool keep_running = true;
        while (keep_running && !shutdown_requested) {
            std::stringstream current_transcription_text; 
            std::string rolling_context = "";
            AudioCapture audioCapture; if (!audioCapture.startCapture()) return 1;
            
            std::thread ui_thread;
            if (showUI) {
                TerminalUI::setEnabled(true);
                TerminalUI::init();
                TerminalUI::clearSegments();
                TerminalUI::setStatus("Recording");
                ui_thread = std::thread([]{ TerminalUI::loop(); });
            }

            float silence_ms = 0; const int chunk_ms = 100; const int chunk_samples = SAMPLE_RATE * chunk_ms / 1000;
            auto start_time = std::chrono::steady_clock::now();
            float total_rms = 0; int rms_count = 0;

            while (!shutdown_requested && !TerminalUI::isFinishRequested()) {
                std::vector<float> chunk;
                if (audioCapture.getAudioChunk(chunk, chunk_samples)) {
                    pcmf32_data.insert(pcmf32_data.end(), chunk.begin(), chunk.end());
                    float rms = calculate_rms(chunk);
                    total_rms += rms; rms_count++;
                    if (showUI) TerminalUI::updateLevel(rms, config.vad_threshold);

                    if (rms < config.vad_threshold) silence_ms += chunk_ms; else silence_ms = 0;
                    float buffer_sec = pcmf32_data.size() / (float)SAMPLE_RATE;

                    if ((silence_ms >= config.vad_silence_ms && buffer_sec > 2.0f) || buffer_sec >= 30.0f) {
                        if (total_rms / rms_count > config.vad_threshold * 0.5f) {
                            if (showUI) TerminalUI::setStatus("Processing...");
                            auto now_steady = std::chrono::steady_clock::now();
                            auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now_steady - start_time).count();
                            int64_t segment_offset_ms = elapsed_ms - (int64_t)(buffer_sec * 1000.0f);

                            auto segments = transcriber.transcribe(pcmf32_data, 4, rolling_context);
                            for (const auto& seg : segments) {
                                std::string txt = seg.text; trim(txt);
                                if (txt.empty() || txt.length() < 2) continue;
                                std::string ts = format_timestamp(seg.t0 * 10 + segment_offset_ms);
                                if (showUI) TerminalUI::addSegment(ts, txt);
                                else std::cout << ts << ": " << txt << std::endl;
                                current_transcription_text << ts << ": " << txt << "\n";
                                rolling_context += " " + txt;
                                if (rolling_context.length() > 200) rolling_context = rolling_context.substr(rolling_context.length() - 200);
                            }
                        }
                        pcmf32_data.clear(); silence_ms = 0; total_rms = 0; rms_count = 0;
                        if (showUI) TerminalUI::setStatus("Recording");
                    }
                } else std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
            audioCapture.stopCapture();
            
            bool is_new = TerminalUI::isNewMeetingRequested();
            if (showUI) { TerminalUI::stop(); if (ui_thread.joinable()) ui_thread.join(); }
            
            std::string transcription = current_transcription_text.str();
            if (!transcription.empty()) {
                auto now = std::chrono::system_clock::now(); auto t_now = std::chrono::system_clock::to_time_t(now);
                std::stringstream ss; ss << std::put_time(std::localtime(&t_now), "%Y%m%d_%H%M%S");
                std::string baseName = "meeting_" + ss.str();
                std::string finalOutputDir = (config.mode == "obsidian") ? config.obsidian_vault_path : config.output_dir;
                fs::create_directories(finalOutputDir);
                std::ofstream(finalOutputDir + "/" + baseName + "_transcript.md") << transcription;

                if (!config.provider.empty()) {
                    auto client = ClientFactory::createClient(config.provider, config.api_key, config.llm_model);
                    if (client) {
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
                            std::stringstream date_ss; date_ss << std::put_time(std::localtime(&t_now), "%Y-%m-%d");
                            std::string fBase = san + "-" + date_ss.str();
                            std::stringstream note;
                            note << "---\ndate: " << date_ss.str() << "\ntitle: \"" << title << "\"\nparticipants: " << (p.empty() ? "[]" : p) << "\ntags: " << (t.empty() ? "[]" : t) << "\nsummary: " << ys << "\n---\n\n";
                            note << "> [!SUMMARY] Meeting Overview\n> " << os << "\n\n## Meeting Details\n\n### Agenda\n" << (ai.empty() ? "- N/A" : ai) << "\n\n### Key Discussion Points\n" << (dp.empty() ? "- N/A" : dp) << "\n\n## Decisions Made\n" << (dm.empty() ? "- N/A" : dm) << "\n\n## Action Items\n" << (acts.empty() ? "- N/A" : acts) << "\n\n## Raw Transcription\n```\n" << transcription << "\n```\n";
                            std::ofstream(finalOutputDir + "/" + fBase + ".md") << note.str();
                        } else {
                            std::string sum = client->generateSummary(SUMMARY_PROMPT + transcription);
                            std::ofstream(finalOutputDir + "/" + baseName + "_summary.md") << "# Meeting Summary\n\n" << sum;
                        }
                    }
                }
            }
            if (!is_new) keep_running = false;
            else TerminalUI::resetNewMeetingRequest();
        }
    } else {
        // File input (keeping existing logic)
        std::ifstream file(wavPath, std::ios::binary); if (!file.is_open()) return 1;
        char buf_h[4]; file.read(buf_h, 4); file.ignore(4); file.read(buf_h, 4);
        uint16_t audioFormat = 0, numChannels = 0, bitsPerSample = 0; uint32_t sampleRate = 0, dataSize = 0;
        while (file.read(buf_h, 4)) {
            std::string id(buf_h, 4); uint32_t size; file.read(reinterpret_cast<char*>(&size), 4);
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
        std::stringstream file_trans;
        for (const auto& seg : segments) {
            std::string ts = format_timestamp(seg.t0 * 10);
            file_trans << ts << ": " << seg.text << "\n";
        }
        std::string transcription = file_trans.str();
        std::string baseName = fs::path(wavPath).stem().string();
        std::string finalOutputDir = (config.mode == "obsidian") ? config.obsidian_vault_path : config.output_dir;
        fs::create_directories(finalOutputDir);
        std::ofstream(finalOutputDir + "/" + baseName + "_transcript.md") << transcription;
        // LLM summary for file omitted for brevity, same as live logic.
    }
    return 0;
}

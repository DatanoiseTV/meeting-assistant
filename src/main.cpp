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
    if (s.empty()) return;
    s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](unsigned char ch) { return !std::isspace(ch); }));
    s.erase(std::find_if(s.rbegin(), s.rend(), [](unsigned char ch) { return !std::isspace(ch); }).base(), s.end());
    if (s.size() >= 2 && s.front() == '"' && s.back() == '"') s = s.substr(1, s.size() - 2);
}

float calculate_rms(const std::vector<float>& samples) {
    if (samples.empty()) return 0.0f;
    float sum_sq = 0.0f;
    for (float s : samples) sum_sq += s * s;
    return std::sqrt(sum_sq / samples.size());
}

std::string format_timestamp(int64_t t_ms) {
    int64_t total_sec = t_ms / 1000;
    int h = (int)(total_sec / 3600);
    int m = (int)((total_sec % 3600) / 60);
    int s = (int)(total_sec % 60);
    char buf[32];
    snprintf(buf, sizeof(buf), "%02d:%02d:%02d", h, m, s);
    return std::string(buf);
}

std::string md_to_html(const std::string& md) {
    std::stringstream html;
    std::istringstream iss(md);
    std::string line;
    bool in_list = false;

    auto process_inline = [](std::string s) {
        // Bold **text**
        size_t b;
        while ((b = s.find("**")) != std::string::npos) {
            size_t e = s.find("**", b + 2);
            if (e != std::string::npos) {
                s.replace(e, 2, "</strong>");
                s.replace(b, 2, "<strong>");
            } else break;
        }
        // Wikilinks [[Text]]
        while ((b = s.find("[[")) != std::string::npos) {
            size_t e = s.find("]]", b + 2);
            if (e != std::string::npos) {
                s.erase(e, 2);
                s.erase(b, 2);
            } else break;
        }
        return s;
    };

    while (std::getline(iss, line)) {
        std::string raw = line;
        trim(line);
        if (line.empty()) continue;

        if (line.rfind("- ", 0) == 0 || line.rfind("* ", 0) == 0) {
            if (!in_list) { html << "<ul>"; in_list = true; }
            std::string content = line.substr(2);
            trim(content);
            // Checkboxes
            if (content.rfind("[ ]", 0) == 0) content = "☐ " + content.substr(3);
            else if (content.rfind("[x]", 0) == 0) content = "☑ " + content.substr(3);
            html << "<li>" << process_inline(content) << "</li>";
        } else {
            if (in_list) { html << "</ul>"; in_list = false; }
            if (line.rfind("### ", 0) == 0) html << "<h4>" << process_inline(line.substr(4)) << "</h4>";
            else if (line.rfind("## ", 0) == 0) html << "<h3>" << process_inline(line.substr(3)) << "</h3>";
            else if (line.rfind("# ", 0) == 0) html << "<h2>" << process_inline(line.substr(2)) << "</h2>";
            else if (line.rfind("> ", 0) == 0) html << "<blockquote>" << process_inline(line.substr(2)) << "</blockquote>";
            else html << "<p>" << process_inline(line) << "</p>";
        }
    }
    if (in_list) html << "</ul>";
    return html.str();
}

void print_usage(const char* prog) {
    std::cout << "Meeting Assistant - Audio Transcription & AI Analysis\n\n";
    std::cout << "Usage: " << prog << " [-f <input.wav> | -l] [options]\n\n";
    std::cout << "Options:\n";
    std::cout << "  -f, --file <path>      Input WAV file.\n";
    std::cout << "  -l, --live             Live transcription mode.\n";
    std::cout << "  --ui                   Show TUI dashboard (requires -l).\n";
    std::cout << "  --persona <p>          'general', 'dev', 'pm', 'exec'.\n";
    std::cout << "  --research             Enable AI grounding (Gemini only).\n";
    std::cout << "  -p <provider>          LLM Provider: ollama, gemini, openai.\n";
    std::cout << "  -k <key>               API Key or base URL.\n";
    std::cout << "  -L <model>             LLM Model name.\n";
    std::cout << "  --obsidian-vault-path  Path to your Obsidian vault root.\n";
    std::cout << "  --save-config          Save provided flags as default.\n";
}

void save_meeting_reports(const std::string& transcription, const Config::Data& config, const std::string& baseName) {
    if (transcription.empty()) return;
    std::string finalOutputDir = (config.mode == "obsidian" && !config.obsidian_vault_path.empty()) ? config.obsidian_vault_path : config.output_dir;
    fs::create_directories(finalOutputDir);
    
    std::string tPath = finalOutputDir + "/" + baseName + "_transcript.md";
    std::ofstream out_t(tPath); out_t << transcription;
    std::cout << "Transcript saved to: " << tPath << "\n";

    if (config.provider.empty()) return;
    auto client = ClientFactory::createClient(config.provider, config.api_key, config.llm_model);
    if (!client) return;

    std::cout << "Generating AI Analysis (" << config.persona << ")..." << std::endl;
    std::string master = client->generateSummary(get_obsidian_prompt(config.persona) + transcription);
    
    if (master.empty() || (master.find("Error") != std::string::npos && master.length() < 150)) {
        std::cerr << "LLM Error: " << master << std::endl;
        return;
    }

    auto ext = [&](const std::string& c, const std::string& s) {
        size_t st = c.find(s); if (st == std::string::npos) return std::string();
        st += s.length(); size_t en = c.find("---", st);
        return c.substr(st, (en == std::string::npos) ? std::string::npos : en - st);
    };
    auto tsec = [](std::string& s) {
        trim(s);
        // Remove trailing delimiters if LLM was sloppy
        if (s.length() >= 3 && s.substr(s.length()-3) == "---") s = s.substr(0, s.length()-3);
        trim(s);
    };

    std::string title = ext(master, "---TITLE---"); tsec(title);
    if (title.empty() || title.length() < 3) title = "Meeting " + baseName;
    
    std::string p = ext(master, "---PARTICIPANTS---"); tsec(p);
    std::string t = ext(master, "---TAGS---"); tsec(t);
    std::string topic = ext(master, "---TOPIC---"); tsec(topic);
    std::string ys = ext(master, "---YAML_SUMMARY---"); tsec(ys);
    std::string os = ext(master, "---OVERVIEW_SUMMARY---"); tsec(os);
    std::string kt = ext(master, "---KEY_TAKEAWAYS---"); tsec(kt);
    std::string ai = ext(master, "---AGENDA_ITEMS---"); tsec(ai);
    std::string dp = ext(master, "---DISCUSSION_POINTS---"); tsec(dp);
    std::string dm = ext(master, "---DECISIONS_MADE---"); tsec(dm);
    std::string qa = ext(master, "---QUESTIONS_ARISEN---"); tsec(qa);
    std::string acts = ext(master, "---ACTION_ITEMS---"); tsec(acts);
    std::string graph = ext(master, "---MERMAID_GRAPH---"); tsec(graph);
    std::string email = ext(master, "---EMAIL_DRAFT---"); tsec(email);

    std::string san = title; for (char& c : san) { if (std::isspace(c)) c = '-'; else if (!std::isalnum(c) && c != '-') c = '_'; }
    auto now = std::chrono::system_clock::now(); auto t_now = std::chrono::system_clock::to_time_t(now);
    std::stringstream date_ss; date_ss << std::put_time(std::localtime(&t_now), "%Y-%m-%d");
    std::string fBase = san + "-" + date_ss.str();

    std::string research;
    if (config.research && config.provider == "gemini") {
        std::cout << "Grounding research..." << std::endl;
        std::this_thread::sleep_for(std::chrono::seconds(2));
        research = client->researchTopics(transcription);
    }

    // Markdown
    std::stringstream note;
    note << "---\ndate: " << date_ss.str() << "\ntype: meeting\ntopic: " << (topic.empty()?"N/A":topic) << "\nparticipants: [" << p << "]\ntags: [" << t << "]\nsummary: " << ys << "\n---\n\n";
    note << "Status:: #processed\n\n> [!ABSTRACT] Summary\n> " << os << "\n\n> [!IMPORTANT] Takeaways\n" << kt << "\n\n";
    if (!research.empty()) note << "> [!INFO] Research\n" << research << "\n\n";
    if (!graph.empty() && graph.length() > 10) note << "## Map\n```mermaid\n" << graph << "\n```\n\n";
    note << "## Meeting Details\n\n### Agenda\n" << ai << "\n\n### Discussion\n" << dp << "\n\n### Questions\n" << qa << "\n\n## Outcomes\n\n### Decisions\n" << dm << "\n\n### Action Items\n" << acts << "\n\n## Appendix\n<details><summary>Transcript</summary>\n\n```\n" << transcription << "\n```\n</details>\n";
    std::ofstream(finalOutputDir + "/" + fBase + ".md") << note.str();

    // HTML (Refined Tidy Design)
    std::stringstream html;
    html << "<!DOCTYPE html><html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'><title>" << title << "</title><style>"
         << "body{font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;line-height:1.6;color:#1a1a1a;max-width:850px;margin:40px auto;padding:20px;background:#f8f9fa}"
         << ".card{background:#fff;padding:40px;border-radius:12px;box-shadow:0 4px 6px rgba(0,0,0,0.05);border:1px solid #e9ecef}"
         << "h1{color:#0056b3;margin-bottom:8px;font-size:2.2em;border-bottom:3px solid #0056b3;padding-bottom:10px} "
         << ".meta{color:#6c757d;font-size:0.95em;margin-bottom:30px} "
         << ".callout{padding:20px;border-radius:8px;margin:25px 0;border-left:6px solid #dee2e6}"
         << ".abstract{background:#e7f3ff;border-left-color:#007bff} .important{background:#fff4e5;border-left-color:#ffc107} .info{background:#eafaf1;border-left-color:#28a745}"
         << "h2{color:#343a40;font-size:1.6em;margin-top:40px;padding-bottom:5px;border-bottom:1px solid #dee2e6} h3{color:#495057;font-size:1.2em;margin-top:25px}"
         << "ul{padding-left:20px} li{margin-bottom:8px} blockquote{font-style:italic;color:#6c757d;border-left:4px solid #dee2e6;padding-left:15px;margin:15px 0}"
         << "pre{background:#212529;color:#f8f9fa;padding:20px;border-radius:8px;overflow-x:auto;font-family:monospace;font-size:0.85em}"
         << "</style></head><body><div class='card'>"
         << "<h1>" << title << "</h1><div class='meta'><strong>Date:</strong> " << date_ss.str() << " | <strong>Attendees:</strong> " << p << "</div>"
         << "<div class='callout abstract'><strong>Summary</strong><p>" << os << "</p></div>"
         << "<div class='callout important'><strong>Key Takeaways</strong>" << md_to_html(kt) << "</div>";
    if (!research.empty()) html << "<div class='callout info'><strong>AI Research</strong>" << md_to_html(research) << "</div>";
    html << "<h2>Meeting Details</h2><h3>Agenda</h3>" << md_to_html(ai) << "<h3>Discussion Points</h3>" << md_to_html(dp);
    if (!qa.empty()) html << "<h3>Questions Arisen</h3>" << md_to_html(qa);
    html << "<h2>Outcomes</h2><h3>Decisions</h3>" << md_to_html(dm) << "<h3>Action Items</h3>" << md_to_html(acts);
    html << "<h2>Appendix</h2><h3>Transcription</h3><pre>" << transcription << "</pre></div></body></html>";
    std::ofstream(finalOutputDir + "/" + fBase + ".html") << html.str();
    
    if (!email.empty()) std::ofstream(finalOutputDir + "/" + fBase + "_email.txt") << email;
    std::cout << "[Success] Reports saved: " << fBase << "\n";
}

int main(int argc, char** argv) {
    std::signal(SIGINT, signal_handler);
    Config::Data config = Config::load();
    std::string wavPath;
    bool liveAudio = false, saveConfig = false, showUI = false;

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if ((arg == "-f" || arg == "--file") && i + 1 < argc) wavPath = argv[++i];
        else if (arg == "-l" || arg == "--live") liveAudio = true;
        else if (arg == "--ui") showUI = true;
        else if (arg == "--research") config.research = true;
        else if (arg == "-m" && i + 1 < argc) config.model_path = argv[++i];
        else if (arg == "-p" && i + 1 < argc) config.provider = argv[++i];
        else if (arg == "-k" && i + 1 < argc) config.api_key = argv[++i];
        else if (arg == "-L" && i + 1 < argc) config.llm_model = argv[++i];
        else if (arg == "-o" && i + 1 < argc) config.output_dir = argv[++i];
        else if (arg == "--mode" && i + 1 < argc) config.mode = argv[++i];
        else if (arg == "--persona" && i + 1 < argc) config.persona = argv[++i];
        else if (arg == "--obsidian-vault-path" && i + 1 < argc) config.obsidian_vault_path = argv[++i];
        else if (arg == "--vad-threshold" && i + 1 < argc) config.vad_threshold = std::stof(argv[++i]);
        else if (arg == "--save-config") saveConfig = true;
        else if (arg == "--help" || arg == "-h") { print_usage(argv[0]); return 0; }
        else { std::cerr << "Unknown arg: " << arg << "\n"; print_usage(argv[0]); return 1; }
    }

    if (saveConfig) { Config::save(config); return 0; }
    if (wavPath.empty() && !liveAudio) { print_usage(argv[0]); return 1; }

    Transcriber transcriber(config.model_path);
    
    if (liveAudio) {
        bool keep_running = true;
        while (keep_running && !shutdown_requested) {
            std::stringstream trans_text; std::string rolling_context = "";
            AudioCapture audioCapture; if (!audioCapture.startCapture()) { std::cerr << "Mic failed.\n"; return 1; }
            std::thread ui_thread;
            if (showUI) {
                TerminalUI::setEnabled(true); TerminalUI::init(); TerminalUI::clearSegments(); TerminalUI::setStatus("Recording");
                ui_thread = std::thread([]{ TerminalUI::loop(); });
            } else { std::cout << "Recording... (Ctrl+C to stop)\n"; }

            float silence_ms = 0; const int chunk_ms = 100; const int chunk_samples = SAMPLE_RATE * chunk_ms / 1000;
            auto start_time = std::chrono::steady_clock::now();
            float total_rms = 0; int rms_count = 0; std::vector<float> pcmf32_data;

            while (!shutdown_requested && !TerminalUI::isFinishRequested()) {
                std::vector<float> chunk;
                if (audioCapture.getAudioChunk(chunk, chunk_samples)) {
                    pcmf32_data.insert(pcmf32_data.end(), chunk.begin(), chunk.end());
                    float rms = calculate_rms(chunk); total_rms += rms; rms_count++;
                    if (showUI) TerminalUI::updateLevel(rms, config.vad_threshold);
                    if (rms < config.vad_threshold) silence_ms += chunk_ms; else silence_ms = 0;
                    float buffer_sec = pcmf32_data.size() / (float)SAMPLE_RATE;
                    if ((silence_ms >= config.vad_silence_ms && buffer_sec > 2.0f) || buffer_sec >= 30.0f) {
                        if (total_rms / rms_count > config.vad_threshold * 0.5f) {
                            if (showUI) TerminalUI::setStatus("Processing...");
                            auto now_st = std::chrono::steady_clock::now(); auto el_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now_st - start_time).count();
                            int64_t off_ms = el_ms - (int64_t)(buffer_sec * 1000.0f);
                            auto segments = transcriber.transcribe(pcmf32_data, 4, rolling_context, [&](int p){ if (showUI) TerminalUI::updateProgress(p); });
                            for (const auto& seg : segments) {
                                std::string txt = seg.text; trim(txt); if (txt.length() < 2) continue;
                                std::string ts = format_timestamp(seg.t0 * 10 + off_ms);
                                if (showUI) TerminalUI::addSegment(ts, txt); else std::cout << ts << ": " << txt << std::endl;
                                trans_text << ts << ": " << txt << "\n"; rolling_context += " " + txt;
                                if (rolling_context.length() > 200) rolling_context = rolling_context.substr(rolling_context.length() - 200);
                            }
                        }
                        pcmf32_data.clear(); silence_ms = 0; total_rms = 0; rms_count = 0; if (showUI) TerminalUI::setStatus("Recording");
                    }
                } else std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
            audioCapture.stopCapture();
            bool is_new = TerminalUI::isNewMeetingRequested();
            if (showUI) { TerminalUI::stop(); if (ui_thread.joinable()) ui_thread.join(); }
            auto now = std::chrono::system_clock::now(); auto t_now = std::chrono::system_clock::to_time_t(now);
            std::stringstream ss; ss << std::put_time(std::localtime(&t_now), "%Y%m%d_%H%M%S");
            save_meeting_reports(trans_text.str(), config, "meeting_" + ss.str());
            if (!is_new) keep_running = false; else TerminalUI::resetNewMeetingRequest();
        }
    } else {
        std::ifstream file(wavPath, std::ios::binary); if (!file.is_open()) return 1;
        char bh[4]; file.read(bh, 4); file.ignore(4); file.read(bh, 4);
        uint16_t af=0, nc=0, bps=0; uint32_t sr=0, ds=0;
        while (file.read(bh, 4)) {
            std::string id(bh, 4); uint32_t csz; file.read(reinterpret_cast<char*>(&csz), 4);
            if (id == "fmt ") { file.read(reinterpret_cast<char*>(&af), 2); file.read(reinterpret_cast<char*>(&nc), 2); file.read(reinterpret_cast<char*>(&sr), 4); file.ignore(6); file.read(reinterpret_cast<char*>(&bps), 2); file.ignore(csz - 16); }
            else if (id == "data") { ds = csz; break; } else file.ignore(csz);
        }
        if (sr == 0) return 1;
        std::vector<char> raw(ds); file.read(raw.data(), ds); file.close();
        std::vector<float> p_raw; size_t ns = ds / (std::max((int)nc, 1) * std::max((int)bps / 8, 1));
        for (size_t i = 0; i < ns; ++i) {
            float s = 0; for (int c = 0; c < nc; ++c) {
                size_t o = (i * nc + c) * (bps / 8);
                if (bps == 16) { int16_t v; std::memcpy(&v, raw.data() + o, 2); s += v / 32768.0f; }
                else if (bps == 32 && af == 3) { float v; std::memcpy(&v, raw.data() + o, 4); s += v; }
            }
            p_raw.push_back(s / std::max((int)nc, 1));
        }
        std::vector<float> p_data;
        if (sr != 16000) {
            double r = 16000.0 / sr; size_t n_new = p_raw.size() * r;
            for (size_t i = 0; i < n_new; ++i) {
                double idx = i / r; size_t x1 = (size_t)idx, x2 = x1 + 1;
                if (x2 >= p_raw.size()) p_data.push_back(p_raw[x1]);
                else p_data.push_back(p_raw[x1] * (1.0 - (idx - x1)) + p_raw[x2] * (idx - x1));
            }
        } else p_data = std::move(p_raw);
        std::cout << "Transcribing file..." << std::endl;
        auto segs = transcriber.transcribe(p_data, 4, "", [&](int p){ std::cout << "\rProgress: [" << p << "%] " << std::flush; });
        std::cout << "\rProgress: [Done]   " << std::endl;
        std::stringstream ft;
        for (const auto& s : segs) ft << format_timestamp(s.t0 * 10) << ": " << s.text << "\n";
        save_meeting_reports(ft.str(), config, fs::path(wavPath).stem().string());
    }
    return 0;
}

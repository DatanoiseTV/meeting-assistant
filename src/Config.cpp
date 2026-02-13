#include "Config.h"
#include <fstream>
#include <iostream>
#include <filesystem>
#include <cstdlib>

namespace fs = std::filesystem;
using json = nlohmann::json;

std::string Config::getConfigPath() {
    const char* home = std::getenv("HOME");
    if (!home) return "config.json";
    fs::path configDir = fs::path(home) / ".meeting_assistant";
    if (!fs::exists(configDir)) {
        fs::create_directories(configDir);
    }
    return (configDir / "config.json").string();
}

Config::Data Config::load() {
    Data data;
    std::string path = getConfigPath();
    std::ifstream f(path);
    if (f.is_open()) {
        try {
            json j;
            f >> j;
            if (j.contains("model_path")) data.model_path = j["model_path"];
            if (j.contains("provider")) data.provider = j["provider"];
            if (j.contains("api_key")) data.api_key = j["api_key"];
            if (j.contains("llm_model")) data.llm_model = j["llm_model"];
            if (j.contains("output_dir")) data.output_dir = j["output_dir"];
            if (j.contains("mode")) data.mode = j["mode"];
            if (j.contains("obsidian_vault_path")) data.obsidian_vault_path = j["obsidian_vault_path"];
            if (j.contains("persona")) data.persona = j["persona"];
            if (j.contains("vad_threshold")) data.vad_threshold = j["vad_threshold"];
            if (j.contains("vad_silence_ms")) data.vad_silence_ms = j["vad_silence_ms"];
        } catch (const std::exception& e) {
            std::cerr << "Error reading config: " << e.what() << std::endl;
        }
    }
    return data;
}

void Config::save(const Data& data) {
    json j;
    j["model_path"] = data.model_path;
    j["provider"] = data.provider;
    j["api_key"] = data.api_key;
    j["llm_model"] = data.llm_model;
    j["output_dir"] = data.output_dir;
    j["mode"] = data.mode;
    j["obsidian_vault_path"] = data.obsidian_vault_path;
    j["persona"] = data.persona;
    j["vad_threshold"] = data.vad_threshold;
    j["vad_silence_ms"] = data.vad_silence_ms;

    std::string path = getConfigPath();
    std::ofstream f(path);
    if (f.is_open()) {
        f << j.dump(4);
        std::cout << "Configuration saved to " << path << std::endl;
    }
}

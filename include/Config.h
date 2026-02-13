#pragma once
#include <string>
#include <nlohmann/json.hpp>

class Config {
public:
    struct Data {
        std::string model_path = "models/ggml-base.en.bin";
        std::string provider;
        std::string api_key;
        std::string llm_model;
        std::string output_dir = "output";
        std::string mode = "standard";
        std::string obsidian_vault_path;
        std::string persona = "general";
        float vad_threshold = 0.01f;
        int vad_silence_ms = 1000;
    };

    static Data load();
    static void save(const Data& data);
    static std::string getConfigPath();
};

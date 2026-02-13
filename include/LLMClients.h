#pragma once
#include <string>
#include <vector>
#include <memory>
#include "HttpClient.h"

class LLMClient {
public:
    virtual ~LLMClient() = default;
    virtual std::string generateSummary(const std::string& transcription) = 0;
    virtual std::string researchTopics(const std::string& transcription) { return ""; }
};

class OllamaClient : public LLMClient {
public:
    OllamaClient(const std::string& model, const std::string& baseUrl = "http://localhost:11434");
    std::string generateSummary(const std::string& transcription) override;
private:
    std::string model; std::string baseUrl; HttpClient httpClient;
};

class GeminiClient : public LLMClient {
public:
    GeminiClient(const std::string& apiKey, const std::string& model = "gemini-2.0-flash");
    std::string generateSummary(const std::string& transcription) override;
    std::string researchTopics(const std::string& transcription) override;
private:
    std::string apiKey; std::string model; HttpClient httpClient;
};

class OpenAIClient : public LLMClient {
public:
    OpenAIClient(const std::string& apiKey, const std::string& model = "gpt-3.5-turbo");
    std::string generateSummary(const std::string& transcription) override;
    std::string researchTopics(const std::string& transcription) override;
private:
    std::string apiKey; std::string model; HttpClient httpClient;
};

class ClientFactory {
public:
    static std::unique_ptr<LLMClient> createClient(const std::string& provider, const std::string& apiKeyOrUrl, const std::string& model);
};

extern const std::string SUMMARY_PROMPT;
extern const std::string TITLE_PROMPT;
std::string get_obsidian_prompt(const std::string& persona);

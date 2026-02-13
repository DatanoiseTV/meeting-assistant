#include "LLMClients.h"
#include <iostream>
#include <sstream>
#include <string>
#include <algorithm>

const std::string SUMMARY_PROMPT = R"(You are a helpful meeting assistant. The following is a raw transcription of a meeting. Please structure this into a clean Markdown note. Include:
1. A concise Summary.
2. Key Discussion Points (bullet points).
3. Action Items / TODOs (with check boxes).
4. Any decisions made.

Transcription:
)";

const std::string TITLE_PROMPT = R"(Based on the following meeting transcription, generate a concise and descriptive title (2-7 words) for the meeting. Your response MUST contain ONLY the title text, as a single line, and nothing else. Transcription:
)";

const std::string OBSIDIAN_MASTER_PROMPT = R"(You are a helpful meeting assistant. The following is a raw transcription of a meeting. Please extract the following information and present it in a clearly delimited plain-text format. Strictly follow the output format described below. DO NOT ADD any other text, explanations, or markdown formatting outside the specified delimiters. Extract information only from the provided transcription.

---PARTICIPANTS---
<Comma-separated list of participant names. Example: John Doe, Jane Smith. Infer from context if not explicit. Leave blank if none.>
---TAGS---
<Comma-separated list of relevant tags (without #). Example: meeting, project-x, AI. Leave blank if none.>
---YAML_SUMMARY---
<A brief, one-sentence overview of the meeting, enclosed in double quotes.>
---OVERVIEW_SUMMARY---
<A concise, 2-3 sentence overview summary paragraph of the entire meeting.>
---AGENDA_ITEMS---
<Key agenda items, as a Markdown bulleted list.>
---DISCUSSION_POINTS---
<Key discussion points, as a Markdown bulleted list. Use wikilinks `[[Link]]` for key concepts/people and `#tags`.>
---DECISIONS_MADE---
<All decisions made, as a Markdown bulleted list. Use wikilinks `[[Link]]` and `#decision` tag.>
---ACTION_ITEMS---
<All action items, as a Markdown bulleted list with checkboxes. Assign to `[[Person]]` with a due date (YYYY-MM-DD) and `#todo` tag.>

Transcription:
)";

OllamaClient::OllamaClient(const std::string& model, const std::string& baseUrl) : model(model), baseUrl(baseUrl) {}
std::string OllamaClient::generateSummary(const std::string& transcription) {
    std::string url = baseUrl + "/api/chat";
    json payload = {{"model", model}, {"messages", {{{"role", "system"}, {"content", "You are a helpful meeting assistant."}}, {{"role", "user"}, {"content", transcription}}}}, {"stream", false}};
    auto response = httpClient.post(url, payload);
    if (response.status_code == 200) { try { auto j = json::parse(response.body); if (j.contains("message") && j["message"].contains("content")) return j["message"]["content"]; } catch (...) {} }
    return "Error calling Ollama: " + std::to_string(response.status_code);
}
GeminiClient::GeminiClient(const std::string& apiKey, const std::string& model) : apiKey(apiKey), model(model) {}
std::string GeminiClient::generateSummary(const std::string& transcription) {
    std::string url = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + apiKey;
    json payload = {{"contents", {{{"role", "user"}, {"parts", {{{"text", "You are a helpful meeting assistant."}}}}}, {{"role", "user"}, {"parts", {{{"text", transcription}}}}}}}};
    auto response = httpClient.post(url, payload);
    if (response.status_code == 200) { try { auto j = json::parse(response.body); if (j.contains("candidates") && !j["candidates"].empty()) return j["candidates"][0]["content"]["parts"][0]["text"]; } catch (...) {} }
    return "Error calling Gemini: " + std::to_string(response.status_code);
}
OpenAIClient::OpenAIClient(const std::string& apiKey, const std::string& model) : apiKey(apiKey), model(model) {}
std::string OpenAIClient::generateSummary(const std::string& transcription) {
    std::string url = "https://api.openai.com/v1/chat/completions";
    json payload = {{"model", model}, {"messages", {{{"role", "system"}, {"content", "You are a helpful meeting assistant."}}, {{"role", "user"}, {"content", transcription}}}}};
    std::map<std::string, std::string> headers = {{"Authorization", "Bearer " + apiKey}};
    auto response = httpClient.post(url, payload, headers);
    if (response.status_code == 200) { try { auto j = json::parse(response.body); if (j.contains("choices") && !j["choices"].empty()) return j["choices"][0]["message"]["content"]; } catch (...) {} }
    return "Error calling OpenAI: " + std::to_string(response.status_code);
}
std::unique_ptr<LLMClient> ClientFactory::createClient(const std::string& provider, const std::string& apiKeyOrUrl, const std::string& model) {
    if (provider == "ollama") return std::make_unique<OllamaClient>(model, apiKeyOrUrl.empty() ? "http://localhost:11434" : apiKeyOrUrl);
    else if (provider == "gemini") return std::make_unique<GeminiClient>(apiKeyOrUrl, model);
    else if (provider == "openai") return std::make_unique<OpenAIClient>(apiKeyOrUrl, model);
    return nullptr;
}

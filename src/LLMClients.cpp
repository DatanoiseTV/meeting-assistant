#include "LLMClients.h"
#include <iostream>
#include <sstream>
#include <string>
#include <algorithm>
#include <map>

const std::string SUMMARY_PROMPT = R"(You are a helpful meeting assistant. The following is a raw transcription of a meeting. Please structure this into a clean Markdown note. Include:
1. A concise Summary.
2. Key Discussion Points (bullet points).
3. Action Items / TODOs (with check boxes).
4. Any decisions made.

Transcription:
)";

const std::string TITLE_PROMPT = R"(Based on the following meeting transcription, generate a concise and descriptive title (2-7 words) for the meeting. Your response MUST contain ONLY the title text, as a single line, and nothing else. Transcription:
)";

std::string get_obsidian_prompt(const std::string& persona) {
    std::string persona_instruction;
    if (persona == "dev") {
        persona_instruction = "You are a Senior Technical Lead. Focus intensely on architectural decisions, code snippets mentioned, technical debt, bugs, and library choices. Ignore marketing fluff.";
    } else if (persona == "pm") {
        persona_instruction = "You are a Project Manager. Focus purely on deliverables, dates, blockers, assignees, and timeline risks. Be concise and action-oriented.";
    } else if (persona == "exec") {
        persona_instruction = "You are an Executive Assistant. Provide a high-level strategic overview. Focus on ROI, key outcomes, and budget impact. Bullet points only. No fluff.";
    } else {
        persona_instruction = "You are a helpful Meeting Assistant. Provide a balanced, comprehensive summary covering all aspects.";
    }

    return persona_instruction + R"(
The following is a raw transcription of a meeting. Please extract the following information and present it in a clearly delimited plain-text format. Strictly follow the output format described below. DO NOT ADD any other text, explanations, or markdown formatting outside the specified delimiters. Extract information only from the provided transcription.

---PARTICIPANTS---
<Comma-separated list of participant names. Example: John Doe, Jane Smith. Infer from context if not explicit. Leave blank if none.>
---TAGS---
<Comma-separated list of relevant tags (without #). Example: meeting, project-x, AI. Leave blank if none.>
---TITLE---
<A concise and descriptive title (2-7 words) for the meeting.>
---TOPIC---
<A 1-3 word primary topic for the meeting. Example: Authentication Refactor.>
---YAML_SUMMARY---
<A brief, one-sentence overview of the meeting, enclosed in double quotes.>
---OVERVIEW_SUMMARY---
<A concise, 2-3 sentence overview summary paragraph of the entire meeting.>
---KEY_TAKEAWAYS---
<3-5 most critical points discussed or decided, as a Markdown bulleted list.>
---AGENDA_ITEMS---
<Key agenda items, as a Markdown bulleted list.>
---DISCUSSION_POINTS---
<Key discussion points, as a Markdown bulleted list. Use wikilinks `[[Link]]` for key concepts/people and `#tags`.>
---DECISIONS_MADE---
<All decisions made, as a Markdown bulleted list. Use wikilinks `[[Link]]` and `#decision` tag.>
---QUESTIONS_ARISEN---
<Any specific questions, uncertainties, or topics requiring further clarification that arose during the meeting, as a Markdown bulleted list.>
---ACTION_ITEMS---
<All action items, as a Markdown bulleted list with checkboxes. Assign to `[[Person]]` with a due date (YYYY-MM-DD) and `#todo` tag.>
---MERMAID_GRAPH---
<A Mermaid.js graph definition (e.g., `graph TD; A-->B;`) visualizing the relationships between discussed topics, people, and decisions. Do not include markdown code block backticks (```mermaid), just the code.>
---EMAIL_DRAFT---
<A professional follow-up email draft summarizing the meeting for the attendees. Include a subject line and body.>

Transcription:
)";
}

OllamaClient::OllamaClient(const std::string& model, const std::string& baseUrl) : model(model), baseUrl(baseUrl) {}
std::string OllamaClient::generateSummary(const std::string& transcription) {
    std::string url = baseUrl + "/api/chat";
    json payload = {{"model", model}, {"messages", {{{"role", "system"}, {"content", "You are a helpful meeting assistant."}}, {{"role", "user"}, {"content", transcription}}}}, {"stream", false}};
    auto response = httpClient.post(url, payload);
    if (response.status_code == 200) { try { auto j = json::parse(response.body); if (j.contains("message") && j["message"].contains("content")) return j["message"]["content"]; } catch (...) {} }
    return "Error calling Ollama: " + std::to_string(response.status_code) + " " + response.error;
}

GeminiClient::GeminiClient(const std::string& apiKey, const std::string& model) : apiKey(apiKey), model(model) {}
std::string GeminiClient::generateSummary(const std::string& transcription) {
    std::string url = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + apiKey;
    json payload = {{"contents", {{{"role", "user"}, {"parts", {{{"text", transcription}}}}}}}};
    auto response = httpClient.post(url, payload);
    if (response.status_code == 200) {
        try {
            auto j = json::parse(response.body);
            if (j.contains("candidates") && !j["candidates"].empty() && j["candidates"][0].contains("content")) {
                return j["candidates"][0]["content"]["parts"][0]["text"];
            }
        } catch (...) {}
    }
    return "Error calling Gemini: " + std::to_string(response.status_code) + " " + response.error + " (Model: " + model + ")";
}
std::string GeminiClient::researchTopics(const std::string& transcription) {
    std::string url = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + apiKey;
    json google_search_tool = {{"google_search", json::object()}};
    json payload = {
        {"contents", {{{"role", "user"}, {"parts", {{{"text", "Research the key technical terms, companies, or concepts mentioned in this meeting transcription. Provide additional context, current trends, or suggestions for each. Use Google Search grounding for accurate information.\n\nTranscription:\n" + transcription}}}}}}},
        {"tools", {google_search_tool}}
    };
    auto response = httpClient.post(url, payload);
    if (response.status_code == 200) {
        try {
            auto j = json::parse(response.body);
            if (j.contains("candidates") && !j["candidates"].empty() && j["candidates"][0].contains("content")) {
                return j["candidates"][0]["content"]["parts"][0]["text"];
            }
        } catch (...) {}
    }
    return "Research failed: " + std::to_string(response.status_code) + " " + response.error;
}

OpenAIClient::OpenAIClient(const std::string& apiKey, const std::string& model) : apiKey(apiKey), model(model) {}
std::string OpenAIClient::generateSummary(const std::string& transcription) {
    std::string url = "https://api.openai.com/v1/chat/completions";
    json payload = {{"model", model}, {"messages", {{{"role", "system"}, {"content", "You are a helpful meeting assistant."}}, {{"role", "user"}, {"content", transcription}}}}};
    std::map<std::string, std::string> headers = {{"Authorization", "Bearer " + apiKey}};
    auto response = httpClient.post(url, payload, headers);
    if (response.status_code == 200) { try { auto j = json::parse(response.body); if (j.contains("choices") && !j["choices"].empty()) return j["choices"][0]["message"]["content"]; } catch (...) {} }
    return "Error calling OpenAI: " + std::to_string(response.status_code) + " " + response.error;
}
std::string OpenAIClient::researchTopics(const std::string& transcription) { return "Research currently only supported for Gemini."; }

std::unique_ptr<LLMClient> ClientFactory::createClient(const std::string& provider, const std::string& apiKeyOrUrl, const std::string& model) {
    if (provider == "ollama") return std::make_unique<OllamaClient>(model, apiKeyOrUrl.empty() ? "http://localhost:11434" : apiKeyOrUrl);
    else if (provider == "gemini") {
        // Use 1.5-flash as the most widely available stable default if none provided
        return std::make_unique<GeminiClient>(apiKeyOrUrl, model.empty() ? "gemini-1.5-flash" : model);
    }
    else if (provider == "openai") return std::make_unique<OpenAIClient>(apiKeyOrUrl, model.empty() ? "gpt-3.5-turbo" : model);
    return nullptr;
}

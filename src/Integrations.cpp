#include "Integrations.h"
#include "Config.h"
#include <iostream>

GitHubTracker::GitHubTracker(const std::string& token, const std::string& repo) : token(token), repo(repo) {}

bool GitHubTracker::createIssue(const std::string& title, const std::string& body) {
    if (token.empty() || repo.empty()) return false;
    std::string url = "https://api.github.com/repos/" + repo + "/issues";
    json payload = {
        {"title", title},
        {"body", body}
    };
    std::map<std::string, std::string> headers = {
        {"Authorization", "token " + token},
        {"Accept", "application/vnd.github.v3+json"},
        {"User-Agent", "Meeting-Assistant"}
    };
    auto response = httpClient.post(url, payload, headers);
    return response.status_code == 201;
}

GitLabTracker::GitLabTracker(const std::string& token, const std::string& repo) : token(token), repo(repo) {}

bool GitLabTracker::createIssue(const std::string& title, const std::string& body) {
    // GitLab repo needs to be URL encoded or ID
    if (token.empty() || repo.empty()) return false;
    // Simple encoding for common cases (user/project)
    std::string encoded_repo = repo;
    for (size_t i = 0; i < encoded_repo.length(); ++i) {
        if (encoded_repo[i] == '/') encoded_repo.replace(i, 1, "%2F");
    }
    
    std::string url = "https://gitlab.com/api/v4/projects/" + encoded_repo + "/issues";
    json payload = {
        {"title", title},
        {"description", body}
    };
    std::map<std::string, std::string> headers = {
        {"PRIVATE-TOKEN", token}
    };
    auto response = httpClient.post(url, payload, headers);
    return response.status_code == 201;
}

std::vector<std::unique_ptr<IssueTracker>> IntegrationFactory::createTrackers(const Config::Data& config) {
    std::vector<std::unique_ptr<IssueTracker>> trackers;
    if (!config.github_token.empty()) {
        trackers.push_back(std::make_unique<GitHubTracker>(config.github_token, config.github_repo));
    }
    if (!config.gitlab_token.empty()) {
        trackers.push_back(std::make_unique<GitLabTracker>(config.gitlab_token, config.gitlab_repo));
    }
    return trackers;
}

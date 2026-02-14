#pragma once
#include <string>
#include <vector>
#include <memory>
#include "HttpClient.h"
#include "Config.h"

class IssueTracker {
public:
    virtual ~IssueTracker() = default;
    virtual bool createIssue(const std::string& title, const std::string& body) = 0;
};

class GitHubTracker : public IssueTracker {
public:
    GitHubTracker(const std::string& token, const std::string& repo);
    bool createIssue(const std::string& title, const std::string& body) override;
private:
    std::string token;
    std::string repo;
    HttpClient httpClient;
};

class GitLabTracker : public IssueTracker {
public:
    GitLabTracker(const std::string& token, const std::string& repo);
    bool createIssue(const std::string& title, const std::string& body) override;
private:
    std::string token;
    std::string repo;
    HttpClient httpClient;
};

class IntegrationFactory {
public:
    static std::vector<std::unique_ptr<IssueTracker>> createTrackers(const struct Config::Data& config);
};

#pragma once
#include <string>
#include <map>
#include <curl/curl.h>
#include <nlohmann/json.hpp>
using json = nlohmann::json;
class HttpClient {
public:
    HttpClient();
    ~HttpClient();
    struct Response { long status_code; std::string body; std::string error; };
    Response post(const std::string& url, const json& payload, const std::map<std::string, std::string>& headers = {});
    Response get(const std::string& url, const std::map<std::string, std::string>& headers = {});
private:
    static size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp);
};

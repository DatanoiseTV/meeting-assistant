#include "HttpClient.h"
#include <iostream>
#include <thread>
#include <chrono>

HttpClient::HttpClient() { curl_global_init(CURL_GLOBAL_ALL); }
HttpClient::~HttpClient() { curl_global_cleanup(); }

size_t HttpClient::WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    ((std::string*)userp)->append((char*)contents, size * nmemb);
    return size * nmemb;
}

HttpClient::Response HttpClient::post(const std::string& url, const json& payload, const std::map<std::string, std::string>& headers) {
    int retries = 0;
    const int max_retries = 3;
    long http_code = 0;
    std::string readBuffer;

    while (retries <= max_retries) {
        readBuffer.clear();
        CURL* curl = curl_easy_init();
        if (curl) {
            curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
            curl_easy_setopt(curl, CURLOPT_POST, 1L);
            std::string json_str = payload.dump();
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json_str.c_str());

            struct curl_slist* chunk = NULL;
            chunk = curl_slist_append(chunk, "Content-Type: application/json");
            for (const auto& header : headers) {
                std::string h = header.first + ": " + header.second;
                chunk = curl_slist_append(chunk, h.c_str());
            }
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, chunk);
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);

            CURLcode res = curl_easy_perform(curl);
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);

            if (res != CURLE_OK) {
                std::string err = curl_easy_strerror(res);
                curl_slist_free_all(chunk);
                curl_easy_cleanup(curl);
                return {http_code, "", err};
            }

            curl_slist_free_all(chunk);
            curl_easy_cleanup(curl);

            // Handle Rate Limiting
            if (http_code == 429) {
                retries++;
                if (retries <= max_retries) {
                    int backoff = (1 << retries); // 2s, 4s, 8s...
                    std::cerr << "Rate limited (429). Retrying in " << backoff << "s..." << std::endl;
                    std::this_thread::sleep_for(std::chrono::seconds(backoff));
                    continue;
                }
            }
            break;
        }
        retries++;
    }
    return {http_code, readBuffer, ""};
}

HttpClient::Response HttpClient::get(const std::string& url, const std::map<std::string, std::string>& headers) {
    CURL* curl; CURLcode res; std::string readBuffer; long http_code = 0;
    curl = curl_easy_init();
    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        struct curl_slist* chunk = NULL;
        for (const auto& header : headers) {
            std::string h = header.first + ": " + header.second;
            chunk = curl_slist_append(chunk, h.c_str());
        }
        if (chunk) curl_easy_setopt(curl, CURLOPT_HTTPHEADER, chunk);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
        res = curl_easy_perform(curl);
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
        if (res != CURLE_OK) return {http_code, "", curl_easy_strerror(res)};
        if (chunk) curl_slist_free_all(chunk);
        curl_easy_cleanup(curl);
    }
    return {http_code, readBuffer, ""};
}

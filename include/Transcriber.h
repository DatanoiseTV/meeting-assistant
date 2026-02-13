#pragma once
#include <string>
#include <vector>
#include <whisper.h>
#include <functional>

struct TranscriptionSegment { int64_t t0; int64_t t1; std::string text; int speaker_id = -1; };

class Transcriber {
public:
    Transcriber(const std::string& modelPath);
    ~Transcriber();
    
    using ProgressCallback = std::function<void(int progress)>;
    
    std::vector<TranscriptionSegment> transcribe(const std::vector<float>& pcmf32, 
                                                int n_threads = 4, 
                                                const std::string& initial_prompt = "",
                                                ProgressCallback callback = nullptr);
private:
    struct whisper_context* ctx = nullptr;
};

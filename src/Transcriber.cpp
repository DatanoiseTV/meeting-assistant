#include "Transcriber.h"
#include <iostream>

Transcriber::Transcriber(const std::string& modelPath) {
    struct whisper_context_params cparams = whisper_context_default_params();
    ctx = whisper_init_from_file_with_params(modelPath.c_str(), cparams);
}

Transcriber::~Transcriber() { if (ctx) whisper_free(ctx); }

std::vector<TranscriptionSegment> Transcriber::transcribe(const std::vector<float>& pcmf32, 
                                                        int n_threads, 
                                                        const std::string& initial_prompt,
                                                        ProgressCallback callback) {
    std::vector<TranscriptionSegment> result; if (!ctx) return result;
    
    whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.language = "en"; 
    wparams.n_threads = n_threads; 
    wparams.tdrz_enable = true;
    
    if (!initial_prompt.empty()) {
        wparams.initial_prompt = initial_prompt.c_str();
    }

    if (callback) {
        wparams.progress_callback = [](struct whisper_context * /*ctx*/, struct whisper_state * /*state*/, int progress, void * user_data) {
            auto* cb = static_cast<ProgressCallback*>(user_data);
            (*cb)(progress);
        };
        wparams.progress_callback_user_data = &callback;
    }

    if (whisper_full(ctx, wparams, pcmf32.data(), pcmf32.size()) != 0) return result;
    
    const int n_segments = whisper_full_n_segments(ctx);
    for (int i = 0; i < n_segments; ++i) {
        result.push_back({whisper_full_get_segment_t0(ctx, i), 
                         whisper_full_get_segment_t1(ctx, i), 
                         whisper_full_get_segment_text(ctx, i)});
    }
    return result;
}

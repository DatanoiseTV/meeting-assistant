#include "AudioCapture.h"
#include <iostream>
AudioCapture::AudioCapture() : stream(nullptr), capturing(false) { Pa_Initialize(); }
AudioCapture::~AudioCapture() { if (capturing) stopCapture(); Pa_Terminate(); }
int AudioCapture::paCallback(const void* in, void* out, unsigned long f, const PaStreamCallbackTimeInfo* t, PaStreamCallbackFlags s, void* u) {
    AudioCapture* This = (AudioCapture*)u; if (!in) return paContinue;
    std::lock_guard<std::mutex> lock(This->audioMutex);
    This->audioBuffer.insert(This->audioBuffer.end(), (float*)in, (float*)in + f);
    This->audioCv.notify_one(); return paContinue;
}
bool AudioCapture::startCapture() {
    PaStreamParameters params; params.device = Pa_GetDefaultInputDevice(); if (params.device == paNoDevice) return false;
    params.channelCount = 1; params.sampleFormat = paFloat32; params.suggestedLatency = Pa_GetDeviceInfo(params.device)->defaultLowInputLatency; params.hostApiSpecificStreamInfo = nullptr;
    if (Pa_OpenStream(&stream, &params, nullptr, SAMPLE_RATE, FRAMES_PER_BUFFER, paClipOff, paCallback, this) != paNoError) return false;
    if (Pa_StartStream(stream) != paNoError) return false;
    capturing = true; return true;
}
bool AudioCapture::stopCapture() { if (!capturing) return false; Pa_StopStream(stream); Pa_CloseStream(stream); capturing = false; return true; }
bool AudioCapture::getAudioChunk(std::vector<float>& chunk, int max) {
    std::unique_lock<std::mutex> lock(audioMutex);
    audioCv.wait(lock, [this, max]{ return !capturing || audioBuffer.size() >= max; });
    if (audioBuffer.empty()) return false;
    int n = std::min((int)audioBuffer.size(), max);
    chunk.assign(audioBuffer.begin(), audioBuffer.begin() + n); audioBuffer.erase(audioBuffer.begin(), audioBuffer.begin() + n);
    return true;
}

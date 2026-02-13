#pragma once
#include <vector>
#include <string>
#include <portaudio.h>
#include <mutex>
#include <condition_variable>
const int SAMPLE_RATE = 16000;
const int FRAMES_PER_BUFFER = 512;
const int NUM_CHANNELS = 1;
class AudioCapture {
public:
    AudioCapture();
    ~AudioCapture();
    bool startCapture();
    bool stopCapture();
    bool getAudioChunk(std::vector<float>& chunk, int max_samples);
private:
    PaStream* stream; std::vector<float> audioBuffer; std::mutex audioMutex; std::condition_variable audioCv; bool capturing;
    static int paCallback(const void* inputBuffer, void* outputBuffer, unsigned long framesPerBuffer, const PaStreamCallbackTimeInfo* timeInfo, PaStreamCallbackFlags statusFlags, void* userData);
};

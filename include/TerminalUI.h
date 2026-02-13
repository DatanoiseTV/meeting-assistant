#pragma once
#include <string>
#include <vector>
#include <mutex>

class TerminalUI {
public:
    static void init();
    static void setStatus(const std::string& status);
    static void updateLevel(float rms, float threshold);
    static void addSegment(const std::string& timestamp, const std::string& text);
    static void clearSegments();
    static void loop(); // Main UI loop
    static bool isEnabled();
    static void setEnabled(bool enabled);
    static bool isFinishRequested();
    static bool isNewMeetingRequested();
    static void resetNewMeetingRequest();
    static void stop();

private:
    static bool enabled;
    static bool running;
    static bool finish_requested;
    static bool new_meeting_requested;
    static std::string current_status;
    static float current_rms;
    static float current_threshold;
    static std::vector<std::pair<std::string, std::string>> segments;
    static std::mutex data_mutex;
};

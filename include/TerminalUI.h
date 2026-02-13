#pragma once
#include <string>
#include <vector>
#include <mutex>

class TerminalUI {
public:
    static void init();
    static void setStatus(const std::string& status);
    static void updateLevel(float rms, float threshold);
    static void updateProgress(int progress);
    static void addSegment(const std::string& timestamp, const std::string& text);
    static void clearSegments();
    static void loop(); 
    static bool isEnabled();
    static void setEnabled(bool enabled);
    
    // Control Flags
    static bool isFinishRequested();
    static bool isNewMeetingRequested();
    static void resetNewMeetingRequest();
    static void stop();

    // Copilot Features
    static bool isCopilotRequested();
    static std::string getCopilotQuestion();
    static void showCopilotResponse(const std::string& response);
    static void resetCopilotRequest();

private:
    static bool enabled;
    static bool running;
    static bool finish_requested;
    static bool new_meeting_requested;
    
    // Copilot State
    static bool copilot_active;
    static bool copilot_input_mode;
    static std::string copilot_question;
    static std::string copilot_response;
    static bool copilot_query_ready;

    static std::string current_status;
    static float current_rms;
    static float current_threshold;
    static int current_progress;
    static std::vector<std::pair<std::string, std::string>> segments;
    static std::mutex data_mutex;
    static std::chrono::steady_clock::time_point start_proc_time;
};

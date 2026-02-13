#include "TerminalUI.h"
#include <ftxui/dom/elements.hpp>
#include <ftxui/screen/screen.hpp>
#include <ftxui/component/component.hpp>
#include <ftxui/component/screen_interactive.hpp>
#include <ftxui/component/event.hpp>
#include <thread>
#include <chrono>
#include <iomanip>

using namespace ftxui;

bool TerminalUI::enabled = false;
bool TerminalUI::running = false;
bool TerminalUI::finish_requested = false;
bool TerminalUI::new_meeting_requested = false;

// Copilot State
bool TerminalUI::copilot_active = false;
bool TerminalUI::copilot_input_mode = false;
std::string TerminalUI::copilot_question = "";
std::string TerminalUI::copilot_response = "";
bool TerminalUI::copilot_query_ready = false;

std::string TerminalUI::current_status = "Initializing";
float TerminalUI::current_rms = 0.0f;
float TerminalUI::current_threshold = 0.01f;
int TerminalUI::current_progress = 0;
std::vector<std::pair<std::string, std::string>> TerminalUI::segments;
std::mutex TerminalUI::data_mutex;
std::chrono::steady_clock::time_point TerminalUI::start_proc_time;

void TerminalUI::init() {
    running = true;
    finish_requested = false;
    copilot_active = false;
    copilot_input_mode = false;
    copilot_query_ready = false;
}

void TerminalUI::setEnabled(bool e) { enabled = e; }
bool TerminalUI::isEnabled() { return enabled; }
bool TerminalUI::isFinishRequested() { return finish_requested; }
bool TerminalUI::isNewMeetingRequested() { return new_meeting_requested; }
void TerminalUI::resetNewMeetingRequest() { new_meeting_requested = false; }

// Copilot Control
bool TerminalUI::isCopilotRequested() { return copilot_query_ready; }
std::string TerminalUI::getCopilotQuestion() { return copilot_question; }
void TerminalUI::resetCopilotRequest() { 
    std::lock_guard<std::mutex> lock(data_mutex);
    copilot_query_ready = false; 
    // Do NOT reset question here, keep it for display
}
void TerminalUI::showCopilotResponse(const std::string& response) {
    std::lock_guard<std::mutex> lock(data_mutex);
    copilot_response = response;
    copilot_input_mode = false; // Switch to viewing mode
}

void TerminalUI::setStatus(const std::string& status) {
    std::lock_guard<std::mutex> lock(data_mutex);
    current_status = status;
    if (status == "Processing...") {
        start_proc_time = std::chrono::steady_clock::now();
        current_progress = 0;
    }
}

void TerminalUI::updateLevel(float rms, float threshold) {
    std::lock_guard<std::mutex> lock(data_mutex);
    current_rms = rms;
    current_threshold = threshold;
}

void TerminalUI::updateProgress(int progress) {
    std::lock_guard<std::mutex> lock(data_mutex);
    current_progress = progress;
}

void TerminalUI::addSegment(const std::string& timestamp, const std::string& text) {
    std::lock_guard<std::mutex> lock(data_mutex);
    segments.push_back({timestamp, text});
    if (segments.size() > 50) segments.erase(segments.begin());
}

void TerminalUI::clearSegments() {
    std::lock_guard<std::mutex> lock(data_mutex);
    segments.clear();
}

void TerminalUI::stop() {
    running = false;
}

void TerminalUI::loop() {
    if (!enabled) return;

    auto screen = ScreenInteractive::Fullscreen();
    int frame_count = 0;

    // Components
    InputOption input_option;
    input_option.on_enter = [&] {
        std::lock_guard<std::mutex> lock(data_mutex);
        if (!copilot_question.empty()) {
            copilot_query_ready = true;
            copilot_response = "Thinking...";
            copilot_input_mode = false; // Wait state
        }
    };
    Component input_component = Input(&copilot_question, "Ask AI...", input_option);

    auto renderer = Renderer(input_component, [&] {
        std::lock_guard<std::mutex> lock(data_mutex);
        frame_count++;
        
        // --- Main Dashboard Layer ---
        bool blink_on = (frame_count / 5) % 2 == 0;
        Element record_icon = (current_status == "Recording") ? text(blink_on ? " ● " : "   ") | color(Color::Red) | bold : text("   ");

        Element status_line = hbox({
            record_icon,
            text(" Status: ") | bold,
            text(current_status) | color(current_status == "Recording" ? Color::Green : Color::Yellow),
            filler(),
            text(" Meeting Assistant Pro ") | color(Color::BlueLight)
        });
        
        Element proc_panel = text("");
        if (current_status == "Processing...") {
            // ... (keep progress logic)
             auto now = std::chrono::steady_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start_proc_time).count();
            std::string eta = "...";
            if (current_progress > 5) {
                int total_est = (int)((float)elapsed / (current_progress / 100.0f));
                int remaining = total_est - (int)elapsed;
                eta = std::to_string(std::max(0, remaining)) + "s";
            }
            proc_panel = vbox({
                hbox({ text(" Progress: "), gauge(current_progress / 100.0f) | flex }) | color(Color::Cyan),
                hbox({ text(" Time: " + std::to_string(elapsed) + "s"), filler(), text(" ETA: " + eta) }) | dim
            }) | border;
        } else {
            float gauge_val = std::min(1.0f, current_rms * 15.0f);
            proc_panel = hbox({
                text(" Mic: [") | bold,
                gauge(gauge_val) | flex | color(current_rms > current_threshold ? Color::Green : Color::Blue),
                text("] ")
            }) | border;
        }

        Elements trans_elements;
        trans_elements.push_back(filler());
        if (segments.empty()) trans_elements.push_back(text("Waiting for speech...") | center | dim);
        else for (const auto& s : segments) trans_elements.push_back(hbox({ text(s.first) | color(Color::GrayDark), text(": "), paragraph(s.second) | flex }));

        Element dashboard = vbox({
            status_line | border,
            proc_panel,
            window(text(" Live Transcription ") | bold, vbox(std::move(trans_elements)) | frame | flex),
            hbox({
                text(" [N] New Meeting ") | bgcolor(Color::Blue) | color(Color::White),
                text(" "),
                text(" [SPACE] AI Copilot ") | bgcolor(Color::Magenta) | color(Color::White),
                text(" "),
                text(" [Q] End ") | inverted,
                filler()
            })
        });

        // --- Copilot Overlay Layer ---
        if (copilot_active) {
            Element content;
            if (copilot_input_mode) {
                content = vbox({
                    text("Ask a question about the meeting so far:"),
                    separator(),
                    input_component->Render() | borderRounded | color(Color::Cyan),
                    text("Press [Enter] to submit, [Esc] to cancel") | dim
                });
            } else {
                content = vbox({
                    text("Q: " + copilot_question) | bold | color(Color::Cyan),
                    separator(),
                    paragraph(copilot_response) | flex,
                    separator(),
                    text("Press [Esc] to close") | dim
                });
            }
            
            return dbox({
                dashboard,
                content | clear_under | center | borderDouble | size(WIDTH, GREATER_THAN, 60) | size(HEIGHT, GREATER_THAN, 10)
            });
        }

        return dashboard;
    });

    auto event_handler = CatchEvent(renderer, [&](Event event) {
        if (copilot_active) {
            if (event == Event::Escape) {
                copilot_active = false;
                copilot_input_mode = false;
                copilot_question = "";
                return true;
            }
            if (copilot_input_mode) {
                return input_component->OnEvent(event);
            }
            return false; // Consume nothing else in view mode
        }

        // Dashboard Hotkeys
        if (event == Event::Character('q') || event == Event::Character('Q')) {
            finish_requested = true;
            return true;
        }
        if (event == Event::Character('n') || event == Event::Character('N')) {
            new_meeting_requested = true;
            finish_requested = true;
            return true;
        }
        if (event == Event::Character(' ')) {
            copilot_active = true;
            copilot_input_mode = true;
            copilot_question = ""; // Reset
            return true;
        }
        return false;
    });

    std::thread refresh_thread([&] {
        while (running && !finish_requested) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            screen.PostEvent(Event::Custom);
        }
        screen.ExitLoopClosure()();
    });

    screen.Loop(event_handler);
    if (refresh_thread.joinable()) refresh_thread.join();
}

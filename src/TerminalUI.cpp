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
}

void TerminalUI::setEnabled(bool e) { enabled = e; }
bool TerminalUI::isEnabled() { return enabled; }
bool TerminalUI::isFinishRequested() { return finish_requested; }
bool TerminalUI::isNewMeetingRequested() { return new_meeting_requested; }
void TerminalUI::resetNewMeetingRequest() { new_meeting_requested = false; }

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

    auto renderer_func = [&] {
        std::lock_guard<std::mutex> lock(data_mutex);
        frame_count++;
        
        bool blink_on = (frame_count / 5) % 2 == 0;
        Element record_icon = (current_status == "Recording") ? text(blink_on ? " ● " : "   ") | color(Color::Red) | bold : text("   ");

        // Status Line
        Element status_line = hbox({
            record_icon,
            text(" Status: ") | bold,
            text(current_status) | color(current_status == "Recording" ? Color::Green : Color::Yellow),
            filler(),
            text(" Meeting Assistant ") | color(Color::BlueLight)
        });
        
        // Processing Info (Progress, ETA)
        Element proc_panel = text("");
        if (current_status == "Processing...") {
            auto now = std::chrono::steady_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start_proc_time).count();
            std::string eta = "Calculating...";
            if (current_progress > 5) {
                int total_est = (int)((float)elapsed / (current_progress / 100.0f));
                int remaining = total_est - (int)elapsed;
                eta = std::to_string(std::max(0, remaining)) + "s";
            }

            proc_panel = vbox({
                hbox({
                    text(" Progress: "), gauge(current_progress / 100.0f) | flex,
                    text(" " + std::to_string(current_progress) + "% ")
                }) | color(Color::Cyan),
                hbox({
                    text(" Elapsed: " + std::to_string(elapsed) + "s"),
                    filler(),
                    text(" ETA: " + eta)
                }) | dim
            }) | border;
        } else {
            // Live level meter
            float gauge_val = std::min(1.0f, current_rms * 15.0f);
            proc_panel = hbox({
                text(" Mic Level: [") | bold,
                gauge(gauge_val) | flex | color(current_rms > current_threshold ? Color::Green : Color::Blue),
                text("] ")
            }) | border;
        }

        // History
        Elements trans_elements;
        trans_elements.push_back(filler());
        if (segments.empty()) {
            trans_elements.push_back(text("Waiting for speech...") | center | dim);
        } else {
            for (const auto& s : segments) {
                trans_elements.push_back(hbox({
                    text(s.first) | color(Color::GrayDark),
                    text(": "),
                    paragraph(s.second) | flex
                }));
            }
        }

        return vbox({
            status_line | border,
            proc_panel,
            window(text(" Live Transcription ") | bold, vbox(std::move(trans_elements)) | frame | flex),
            hbox({
                text(" [N] New Meeting ") | bgcolor(Color::Blue) | color(Color::White),
                text("  "),
                text(" [Q/ESC] End & Summarize ") | inverted,
                filler()
            })
        });
    };

    auto component = Renderer(renderer_func);

    auto event_handler = CatchEvent(component, [&](Event event) {
        if (event == Event::Character('q') || event == Event::Character('Q') || event == Event::Escape) {
            finish_requested = true;
            return true;
        }
        if (event == Event::Character('n') || event == Event::Character('N')) {
            new_meeting_requested = true;
            finish_requested = true;
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

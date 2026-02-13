#include "TerminalUI.h"
#include <ftxui/dom/elements.hpp>
#include <ftxui/screen/screen.hpp>
#include <ftxui/component/component.hpp>
#include <ftxui/component/screen_interactive.hpp>
#include <ftxui/component/event.hpp>
#include <thread>
#include <chrono>

using namespace ftxui;

bool TerminalUI::enabled = false;
bool TerminalUI::running = false;
bool TerminalUI::finish_requested = false;
bool TerminalUI::new_meeting_requested = false;
std::string TerminalUI::current_status = "Initializing";
float TerminalUI::current_rms = 0.0f;
float TerminalUI::current_threshold = 0.01f;
std::vector<std::pair<std::string, std::string>> TerminalUI::segments;
std::mutex TerminalUI::data_mutex;

void TerminalUI::init() {
    running = true;
    finish_requested = false;
    new_meeting_requested = false;
}

void TerminalUI::setEnabled(bool e) { enabled = e; }
bool TerminalUI::isEnabled() { return enabled; }
bool TerminalUI::isFinishRequested() { return finish_requested; }
bool TerminalUI::isNewMeetingRequested() { return new_meeting_requested; }
void TerminalUI::resetNewMeetingRequest() { new_meeting_requested = false; }

void TerminalUI::setStatus(const std::string& status) {
    std::lock_guard<std::mutex> lock(data_mutex);
    current_status = status;
}

void TerminalUI::updateLevel(float rms, float threshold) {
    std::lock_guard<std::mutex> lock(data_mutex);
    current_rms = rms;
    current_threshold = threshold;
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

    auto renderer = Renderer([&] {
        std::lock_guard<std::mutex> lock(data_mutex);
        frame_count++;
        
        bool blink_on = (frame_count / 5) % 2 == 0;
        Element record_icon = text("");
        if (current_status == "Recording") {
            record_icon = text(blink_on ? " ● " : "   ") | color(Color::Red) | bold;
        }

        // Status Bar
        Element status_color = (current_status == "Recording") ? text(current_status) | color(Color::Green) : text(current_status) | color(Color::Yellow);
        Element status_line = hbox({
            record_icon,
            text(" Status: ") | bold,
            status_color,
            filler(),
            text(" Meeting Assistant ") | color(Color::BlueLight)
        });
        
        // Meter
        float gauge_val = std::min(1.0f, current_rms * 15.0f);
        Element meter = hbox({
            text(" Mic Level: [") | bold,
            gauge(gauge_val) | flex | color(current_rms > current_threshold ? Color::Green : Color::Blue),
            text("] ")
        });

        // Transcription History
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

        auto trans_window = window(text(" Live Transcription ") | bold, 
                                   vbox(std::move(trans_elements)) | frame | flex);

        auto footer = hbox({
            text(" [N] New Meeting ") | bgcolor(Color::Blue) | color(Color::White),
            text("  "),
            text(" [Q/ESC] End & Summarize ") | inverted,
            filler(),
            text(" Thr: " + std::to_string((int)(current_threshold * 1000))) | dim
        });

        return vbox({
            status_line | border,
            meter | border,
            trans_window | flex,
            footer
        });
    });

    auto component = CatchEvent(renderer, [&](Event event) {
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

    screen.Loop(component);
    if (refresh_thread.joinable()) refresh_thread.join();
}

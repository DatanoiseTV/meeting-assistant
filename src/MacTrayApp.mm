#import <Cocoa/Cocoa.h>
#include "MacTrayApp.h"
#include "AudioCapture.h"
#include "Transcriber.h"
#include "LLMClients.h"
#include "Config.h"
#include <thread>
#include <atomic>
#include <sstream>

// --- Objective-C Implementation ---
@interface MacTrayAppImpl : NSObject {
    NSStatusItem *_statusItem;
    MacTrayApp *_appBridge;
    NSMenuItem *_recordMenuItem;
    BOOL _isRecording;
}
- (instancetype)initWithBridge:(MacTrayApp *)bridge;
- (void)setupUI;
- (void)startStopClicked:(id)sender;
- (void)newMeetingClicked:(id)sender;
- (void)quitClicked:(id)sender;
@end

@implementation MacTrayAppImpl

- (instancetype)initWithBridge:(MacTrayApp *)bridge {
    self = [super init];
    if (self) {
        _appBridge = bridge;
        _isRecording = NO;
    }
    return self;
}

- (void)setupUI {
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.button.title = @"🎤";
    
    NSMenu *menu = [[NSMenu alloc] init];
    
    _recordMenuItem = [[NSMenuItem alloc] initWithTitle:@"Start Recording" action:@selector(startStopClicked:) keyEquivalent:@"r"];
    [menu addItem:_recordMenuItem];
    
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"New Meeting" action:@selector(newMeetingClicked:) keyEquivalent:@"n"]];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quitClicked:) keyEquivalent:@"q"]];
    
    _statusItem.menu = menu;
}

- (void)startStopClicked:(id)sender {
    if (!_isRecording) {
        _isRecording = YES;
        _recordMenuItem.title = @"Stop Recording";
        _statusItem.button.title = @"🔴";
        _appBridge->onStartRecording();
    } else {
        _isRecording = NO;
        _recordMenuItem.title = @"Start Recording";
        _statusItem.button.title = @"🎤";
        _appBridge->onStopRecording();
    }
}

- (void)newMeetingClicked:(id)sender {
    _appBridge->onNewMeeting();
}

- (void)quitClicked:(id)sender {
    [NSApp terminate:nil];
}

@end

// --- C++ Bridge Implementation ---

#include <iostream>

class Engine {
public:
    std::unique_ptr<AudioCapture> capture;
    std::unique_ptr<Transcriber> transcriber;
    std::stringstream transcript;
    std::atomic<bool> active{false};
    std::thread worker;
    Config::Data config;

    Engine() {
        config = Config::load();
        transcriber = std::make_unique<Transcriber>(config.model_path);
    }

    void start() {
        if (active) return;
        active = true;
        capture = std::make_unique<AudioCapture>();
        capture->startCapture();
        
        worker = std::thread([this]() {
            std::vector<float> pcmf32;
            while (active) {
                std::vector<float> chunk;
                if (capture->getAudioChunk(chunk, SAMPLE_RATE)) {
                    pcmf32.insert(pcmf32.end(), chunk.begin(), chunk.end());
                    if (pcmf32.size() >= SAMPLE_RATE * 5) {
                        auto segments = transcriber->transcribe(pcmf32, 4, "", nullptr);
                        pcmf32.clear();
                        for (const auto& s : segments) transcript << s.text << "\n";
                    }
                }
            }
        });
    }

    void stop() {
        active = false;
        if (worker.joinable()) worker.join();
        if (capture) capture->stopCapture();
        std::cout << "Meeting ended. Transcription size: " << transcript.str().length() << std::endl;
    }
};

static Engine* g_engine = nullptr;

MacTrayApp::MacTrayApp() {
    impl = (MacTrayAppImpl*)[[MacTrayAppImpl alloc] initWithBridge:this];
    g_engine = new Engine();
}

MacTrayApp::~MacTrayApp() {
    // Correct cast for non-ARC or standard Objective-C usage in this context
    MacTrayAppImpl* obj = (MacTrayAppImpl*)impl;
    [obj release];
    delete g_engine;
}

void MacTrayApp::run() {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [(id)impl setupUI];
    [NSApp run];
}

void MacTrayApp::onStartRecording() { g_engine->start(); }
void MacTrayApp::onStopRecording() { g_engine->stop(); }
void MacTrayApp::onNewMeeting() { g_engine->stop(); g_engine->transcript.str(""); g_engine->start(); }
void MacTrayApp::onOpenSettings() { /* TODO */ }
void MacTrayApp::stop() { [NSApp terminate:nil]; }

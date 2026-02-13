#pragma once
#include <string>
#include <memory>
#include "Config.h"

// Forward declaration of the Objective-C class
#ifdef __OBJC__
@class MacTrayAppImpl;
#else
typedef void MacTrayAppImpl;
#endif

class MacTrayApp {
public:
    MacTrayApp();
    ~MacTrayApp();

    void run();
    void stop();

    // Callbacks for the UI to interact with the engine
    void onStartRecording();
    void onStopRecording();
    void onNewMeeting();
    void onOpenSettings();

private:
    MacTrayAppImpl* impl;
};

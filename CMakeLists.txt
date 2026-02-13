cmake_minimum_required(VERSION 3.14)
project(MeetingAssistant CXX OBJCXX) # Added OBJCXX

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Dependencies
include(FetchContent)

# 1. whisper.cpp
FetchContent_Declare(
    whisper
    GIT_REPOSITORY https://github.com/ggerganov/whisper.cpp.git
    GIT_TAG        master
)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(whisper)

# 2. nlohmann/json
FetchContent_Declare(
    json
    GIT_REPOSITORY https://github.com/nlohmann/json.git
    GIT_TAG        v3.11.3
)
FetchContent_MakeAvailable(json)

# 3. FTXUI
FetchContent_Declare(
    ftxui
    GIT_REPOSITORY https://github.com/ArthurSonzogni/ftxui
    GIT_TAG        v5.0.0
)
FetchContent_MakeAvailable(ftxui)

# 4. libcurl (System)
find_package(CURL REQUIRED)

# Source files
file(GLOB_RECURSE SOURCES "src/*.cpp" "src/*.mm") # Added .mm

# Executable
add_executable(meeting_assistant ${SOURCES})

# Include directories
target_include_directories(meeting_assistant PRIVATE 
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${whisper_SOURCE_DIR}
    ${json_SOURCE_DIR}/include
    /opt/homebrew/include
)

# Link directories for PortAudio
link_directories(/opt/homebrew/lib)

# Link libraries
target_link_libraries(meeting_assistant PRIVATE 
    whisper
    nlohmann_json::nlohmann_json
    ftxui::screen
    ftxui::dom
    ftxui::component
    CURL::libcurl
    /opt/homebrew/lib/libportaudio.dylib
)

# Native macOS Frameworks
if(APPLE)
    find_library(COCOA_LIBRARY Cocoa)
    find_library(APPKIT_LIBRARY AppKit)
    target_link_libraries(meeting_assistant PRIVATE ${COCOA_LIBRARY} ${APPKIT_LIBRARY})
endif()

# Copy models folder to build directory
add_custom_command(TARGET meeting_assistant POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${CMAKE_CURRENT_SOURCE_DIR}/models
    $<TARGET_FILE_DIR:meeting_assistant>/models
)

# Install
install(TARGETS meeting_assistant DESTINATION bin)
install(DIRECTORY models DESTINATION share/meeting_assistant)

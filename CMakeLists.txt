cmake_minimum_required(VERSION 3.14)
project(MeetingAssistant CXX)

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

# 3. libcurl (System)
find_package(CURL REQUIRED)

# Source files
file(GLOB_RECURSE SOURCES "src/*.cpp")

# Executable
add_executable(meeting_assistant ${SOURCES})

# Include directories
target_include_directories(meeting_assistant PRIVATE 
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${whisper_SOURCE_DIR} # To include whisper.h
    ${json_SOURCE_DIR}/include
    /opt/homebrew/include # PortAudio include
)

# Link directories for PortAudio
link_directories(/opt/homebrew/lib)

# Link libraries
target_link_libraries(meeting_assistant PRIVATE 
    whisper
    nlohmann_json::nlohmann_json
    CURL::libcurl
    /opt/homebrew/lib/libportaudio.dylib # PortAudio library
)

# Copy models folder to build directory
add_custom_command(TARGET meeting_assistant POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${CMAKE_CURRENT_SOURCE_DIR}/models
    $<TARGET_FILE_DIR:meeting_assistant>/models
)

# Install
install(TARGETS meeting_assistant DESTINATION bin)
install(DIRECTORY models DESTINATION share/meeting_assistant)

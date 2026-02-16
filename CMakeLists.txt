cmake_minimum_required(VERSION 3.16)

project(SaberPlayer VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Fixed: Ask for QuickControls2 AND Multimedia
find_package(Qt6 REQUIRED COMPONENTS Quick Concurrent QuickControls2 Multimedia)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appSaberPlayer
    main.cpp
    appicon.rc

)

qt_add_qml_module(appSaberPlayer
    URI SaberPlayer
    VERSION 1.0
    QML_FILES
        Main.qml
        ControlDeck.qml
        SideBar.qml
        CentralDisplay.qml
        LibraryView.qml
    SOURCES
        playercontroller.h
        playercontroller.cpp
        settingsmanager.h
        settingsmanager.cpp
        librarymodel.h
        librarymodel.cpp
        QML_FILES CdView.qml
        SOURCES cdmanager.h cdmanager.cpp
        RESOURCES
                logo.png
)

# Setup VLC SDK Paths
set(VLC_SDK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/libs/sdk-vlc-3.0.23")
target_include_directories(appSaberPlayer PRIVATE "${VLC_SDK_DIR}/include")
target_link_directories(appSaberPlayer PRIVATE "${VLC_SDK_DIR}/lib")

set_target_properties(appSaberPlayer PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

# Fixed: Link both QuickControls2 AND Multimedia so the visualizer builds!
target_link_libraries(appSaberPlayer
    PRIVATE
        Qt6::Quick
        Qt6::Concurrent
        Qt6::QuickControls2
        Qt6::Multimedia
        libvlc.lib
        libvlccore.lib
)

# --- AUTOMATICALLY COPY VLC DLLS & PLUGINS ---
add_custom_command(TARGET appSaberPlayer POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${VLC_SDK_DIR}/bin/libvlc.dll"
        "$<TARGET_FILE_DIR:appSaberPlayer>/libvlc.dll"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${VLC_SDK_DIR}/bin/libvlccore.dll"
        "$<TARGET_FILE_DIR:appSaberPlayer>/libvlccore.dll"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${VLC_SDK_DIR}/plugins"
        "$<TARGET_FILE_DIR:appSaberPlayer>/plugins"
    # NEW: Copy the Lua scripts so VLC can access the internet!
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${VLC_SDK_DIR}/lua"
        "$<TARGET_FILE_DIR:appSaberPlayer>/lua"
    COMMENT "Copying VLC runtime files..."
)

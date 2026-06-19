cmake_minimum_required(VERSION 3.16)

project(qt-dashboard VERSION 0.1.0 LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(qt-dashboard
    src/main.cpp
)

set_source_files_properties(fonts/DejaVuSans.ttf PROPERTIES
    QT_RESOURCE_ALIAS "DejaVuSans.ttf"
)
set_source_files_properties(fonts/DejaVuSans-Bold.ttf PROPERTIES
    QT_RESOURCE_ALIAS "DejaVuSans-Bold.ttf"
)

qt_add_resources(qt-dashboard dashboard_fonts
    PREFIX "/fonts"
    FILES
        fonts/DejaVuSans.ttf
        fonts/DejaVuSans-Bold.ttf
)

qt_add_qml_module(qt-dashboard
    URI QtDashboard
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

target_link_libraries(qt-dashboard PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
)

install(TARGETS qt-dashboard
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

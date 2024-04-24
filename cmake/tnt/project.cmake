include_guard(GLOBAL)

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

function(tnt_project__set_version_from_git)

    # This function requires the Git package to function
    find_package(Git REQUIRED)

    # Use "git describe" to get version information from Git
    execute_process(
            COMMAND ${GIT_EXECUTABLE} describe --dirty --long --match=v* --tags
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
            RESULT_VARIABLE git_result
            OUTPUT_VARIABLE git_output OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_VARIABLE git_error ERROR_STRIP_TRAILING_WHITESPACE)

    # If the result is not "0" an error has occurred
    if (git_result)
        message(FATAL_ERROR ${git_error})
    endif ()

    # Parse the version string returned by Git
    # Format is "v<MAJOR>.<MINOR>.<PATCH>-<TWEAK>-<GIT_HASH>[-dirty]"
    if (git_output MATCHES "^v([0-9]+)[.]([0-9]+)[.]([0-9]+)-([0-9]+)")
        set(version_major ${CMAKE_MATCH_1})
        set(version_minor ${CMAKE_MATCH_2})
        set(version_patch ${CMAKE_MATCH_3})
        set(version_tweak ${CMAKE_MATCH_4})

        string(APPEND version "${version_major}.${version_minor}.${version_patch}")
    else ()
        message(FATAL_ERROR "Git returned an invalid version: ${git_output}")
    endif ()

    # The version is considered dirty if there are uncommitted local changes
    if (git_output MATCHES "-dirty$")
        set(version_is_dirty TRUE)
    else ()
        set(version_is_dirty FALSE)
    endif ()

    # Use "git log" to get the current commit hash from Git
    execute_process(
            COMMAND ${GIT_EXECUTABLE} log -1 --pretty=format:%H
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
            RESULT_VARIABLE git_result
            OUTPUT_VARIABLE git_output OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_VARIABLE git_error ERROR_STRIP_TRAILING_WHITESPACE)

    # If the result is not "0" an error has occurred
    if (git_result)
        message(FATAL_ERROR ${git_error})
    endif ()

    set(version_git_hash ${git_output})

    # Set global CMake variables containing project version information
    set(PROJECT_VERSION ${version} PARENT_SCOPE)
    set(PROJECT_VERSION_MAJOR ${version_major} PARENT_SCOPE)
    set(PROJECT_VERSION_MINOR ${version_minor} PARENT_SCOPE)
    set(PROJECT_VERSION_PATCH ${version_patch} PARENT_SCOPE)
    set(PROJECT_VERSION_TWEAK ${version_tweak} PARENT_SCOPE)
    set(PROJECT_VERSION_IS_DIRTY ${version_is_dirty} PARENT_SCOPE)
    set(PROJECT_VERSION_HASH ${version_git_hash} PARENT_SCOPE)

    set(${PROJECT_NAME}_VERSION ${version} PARENT_SCOPE)
    set(${PROJECT_NAME}_VERSION_MAJOR ${version_major} PARENT_SCOPE)
    set(${PROJECT_NAME}_VERSION_MINOR ${version_minor} PARENT_SCOPE)
    set(${PROJECT_NAME}_VERSION_PATCH ${version_patch} PARENT_SCOPE)
    set(${PROJECT_NAME}_VERSION_TWEAK ${version_tweak} PARENT_SCOPE)
    set(${PROJECT_NAME}_VERSION_IS_DIRTY ${version_is_dirty} PARENT_SCOPE)
    set(${PROJECT_NAME}_VERSION_HASH ${version_git_hash} PARENT_SCOPE)
endfunction()

function(tnt_project__set_namespace args_NAMESPACE)
    set(PROJECT_NAMESPACE ${args_NAMESPACE} PARENT_SCOPE)
    set(${PROJECT_NAME}_NAMESPACE ${args_NAMESPACE} PARENT_SCOPE)
endfunction()

function(tnt_project__add_executable)
    set(options)
    set(one_value_args TARGET)
    set(multi_value_args SOURCES)
    cmake_parse_arguments(args "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

    # Create the executable
    add_executable(${args_TARGET} ${args_SOURCES})

    # Initialize default include directories
    set(private_include_dir "${PROJECT_SOURCE_DIR}/include/${args_TARGET}")

    # Handle namespace considerations
    if (PROJECT_NAMESPACE)
        set(private_include_dir "${PROJECT_SOURCE_DIR}/include/${PROJECT_NAMESPACE}/${args_TARGET}")
    endif ()

    # Set default include directories
    target_include_directories(${args_TARGET}
            PRIVATE
            ${PROJECT_SOURCE_DIR}/include
            ${private_include_dir}
            ${PROJECT_SOURCE_DIR}/src)
endfunction()

function(tnt_project__add_library)
    set(options INTERFACE)
    set(one_value_args TARGET)
    set(multi_value_args SOURCES)
    cmake_parse_arguments(args "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

    # Create the library
    if (${args_INTERFACE})
        add_library(${args_TARGET} INTERFACE ${args_UNPARSED_ARGUMENTS})
    else ()
        add_library(${args_TARGET} ${args_SOURCES} ${args_UNPARSED_ARGUMENTS})

        # Handle RPATH considerations for shared libraries
        # See "Deep CMake for Library Authors" https://www.youtube.com/watch?v=m0DwB4OvDXk
        set_target_properties(${args_TARGET} PROPERTIES BUILD_RPATH_USE_ORIGIN TRUE)
    endif ()

    # Initialize default include directories
    set(private_include_dir "${PROJECT_SOURCE_DIR}/include/${args_TARGET}")

    # Handle namespace considerations
    if (PROJECT_NAMESPACE)
        add_library(${PROJECT_NAMESPACE}::${args_TARGET} ALIAS ${args_TARGET})
        set(private_include_dir "${PROJECT_SOURCE_DIR}/include/${PROJECT_NAMESPACE}/${args_TARGET}")
    endif ()

    # Set default include directories
    if (${args_INTERFACE})
        target_include_directories(${args_TARGET}
                INTERFACE
                $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
                $<INSTALL_INTERFACE:include>)
    else ()
        target_include_directories(${args_TARGET}
                PUBLIC
                $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
                $<INSTALL_INTERFACE:include>
                PRIVATE
                $<BUILD_INTERFACE:${private_include_dir}>
                $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>)
    endif ()
endfunction()

function(tnt_project__install)
    set(options)
    set(one_value_args)
    set(multi_value_args TARGETS)
    cmake_parse_arguments(args "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

    # Validate input arguments
    if (NOT args_TARGETS)
        message(FATAL_ERROR "Missing required input argument 'TARGETS'.")
    endif ()

    # Set the install destination and namespace
    set(install_destination "lib/cmake/${PROJECT_NAME}")
    if (PROJECT_NAMESPACE)
        set(install_namespace "${PROJECT_NAMESPACE}::")
    endif ()

    # Create an export package of the targets
    # Use GNUInstallDirs and COMPONENTS
    # See "Deep CMake for Library Authors" https://www.youtube.com/watch?v=m0DwB4OvDXk
    # TODO: Investigate why using "COMPONENTS" broke usage of the package
    install(
            TARGETS ${args_TARGETS}
            EXPORT ${PROJECT_NAME}-targets
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
            #COMPONENT ${PROJECT_NAME}_Development
            INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            #COMPONENT ${PROJECT_NAME}_Development
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
            #COMPONENT ${PROJECT_NAME}_Runtime
            #NAMELINK_COMPONENT ${PROJECT_NAME}_Development
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
            #COMPONENT ${PROJECT_NAME}_Runtime)

    # Install the export package
    install(
            EXPORT ${PROJECT_NAME}-targets
            FILE ${PROJECT_NAME}-targets.cmake
            NAMESPACE ${install_namespace}
            DESTINATION ${install_destination})

    # Generate a package configuration file
    file(
            WRITE ${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config.cmake.in
            "@PACKAGE_INIT@\n"
            "include(\${CMAKE_CURRENT_LIST_DIR}/${PROJECT_NAME}-targets.cmake)")
    configure_package_config_file(
            ${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config.cmake.in
            ${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config.cmake
            INSTALL_DESTINATION ${install_destination})

    # Gather files to be installed
    list(APPEND install_files ${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config.cmake)

    # If the package has a version specified, generate a package version file
    if (PROJECT_VERSION)
        write_basic_package_version_file(${PROJECT_NAME}-config-version.cmake
                VERSION ${PROJECT_VERSION}
                COMPATIBILITY SameMajorVersion)

        list(APPEND install_files ${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config-version.cmake)
    endif ()

    # Install config files for the project
    install(
            FILES ${install_files}
            DESTINATION ${install_destination})

    # Install public header files for the project
    install(
            DIRECTORY ${PROJECT_SOURCE_DIR}/include/
            DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            FILES_MATCHING PATTERN "*.h*")
endfunction()

# cmake

cmake contains a collection of useful CMake modules that can be easily integrated into any CMake
project.

## Usage

Using these modules is very straightforward. Simply add this repository to your project in a git
submodule and then directly include the modules from within the CMakeLists.txt file.

    git submodule add https://gitlab.com/tnt-coders/cpp/cmake/cmake.git

Then add the modules to the `CMAKE_MODULE_PATH`

**CMakeLists.txt**

    # Include the required modules
    list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
    include(tnt/project)

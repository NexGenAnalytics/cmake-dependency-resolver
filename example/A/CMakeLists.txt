project(A LANGUAGES NONE)
cmake_minimum_required(VERSION 3.19 FATAL_ERROR)

#------------------------------------------------------------------------------#

include(../../cmake/DependencyResolver.cmake)

add_and_resolve_package_dependencies(${CMAKE_CURRENT_BINARY_DIR}/upstream)

#------------------------------------------------------------------------------#

# TODO: test if upstream packages and their components were configured properly
#       Alternative: add Python tests that parse CMake outputs for different
#                    build option sets

message("@ Configured ${PACKAGE_NAME}: ${PACKAGE_COMPONENTS}")
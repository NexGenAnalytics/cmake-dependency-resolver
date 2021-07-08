project(X LANGUAGES NONE)
cmake_minimum_required(VERSION 3.19 FATAL_ERROR)

#------------------------------------------------------------------------------#
#
include(../../DependencyResolver.cmake)

add_and_resolve_package_dependencies(${CMAKE_CURRENT_BINARY_DIR}/upstream)

#------------------------------------------------------------------------------#

message("@ Configured ${PACKAGE_NAME}: ${PACKAGE_COMPONENTS}")
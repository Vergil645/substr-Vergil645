cmake_minimum_required(VERSION 3.17)
project(substr_task)

set(CMAKE_CXX_STANDARD 14)

execute_process(COMMAND stack setup WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
add_custom_target(haskell-tests ALL stack build WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wno-sign-compare -pedantic")

add_executable(solution solution.cpp)

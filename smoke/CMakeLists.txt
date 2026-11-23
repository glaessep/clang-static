cmake_minimum_required(VERSION 3.20)
project(clang_static_smoke CXX)

find_package(Clang REQUIRED CONFIG)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(smoke main.cpp)
target_include_directories(smoke PRIVATE ${CLANG_INCLUDE_DIRS} ${LLVM_INCLUDE_DIRS})
target_compile_definitions(smoke PRIVATE ${LLVM_DEFINITIONS_LIST})
# The libraries are built without RTTI. The program must match.
if(NOT LLVM_ENABLE_RTTI AND NOT MSVC)
  target_compile_options(smoke PRIVATE -fno-rtti)
endif()
target_link_libraries(smoke PRIVATE clangTooling clangIndex)

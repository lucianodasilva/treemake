cmake_minimum_required (VERSION 3.12)

enable_testing()

include (${CMAKE_CURRENT_LIST_DIR}/../../cmake/treemake.cmake)

add_library_dir (target_1 SHARED)
add_executable_dir (target_2 PUBLIC target_1)
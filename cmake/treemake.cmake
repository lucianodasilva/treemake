cmake_minimum_required (VERSION 3.12)

list (APPEND TREEMAKE_PRIVATE_DIR source src)
list (APPEND TREEMAKE_PUBLIC_DIR include)
list (APPEND TREEMAKE_MODULE_DIR modules)
list (APPEND TREEMAKE_TEST_DIR test)
list (APPEND TREEMAKE_SOURCE_EXT c cpp cxx)
list (APPEND TREEMAKE_HEADER_EXT h hpp hxx)

option (TREEMAKE_ENABLE_TESTING "Enable testing targets" TRUE)

function (dir_target_name target_name)
    set (${target_name} ${_current_dir_target_name})
endfunction()

function (_include_for_target cmake_file target_name)
    set (_current_target_name ${target_name} PARENT_SCOPE)
    include (${cmake_file})
endfunction()

function (_get_directories path result)
    file (GLOB children RELATIVE ${path} ${path}/*)
    set (directories "")

    foreach (child ${children})
        if (IS_DIRECTORY ${path}/${child})
            list(APPEND directories "${path}/${child}")
        endif()
    endforeach()

    set (${result} ${directories} PARENT_SCOPE)
endfunction()

function (_evaluate_path directory path)
    if (EXISTS ${CMAKE_CURRENT_LIST_DIR}/${directory})
        set (${path} ${CMAKE_CURRENT_LIST_DIR}/${directory} PARENT_SCOPE)
    else ()
        if (EXISTS ${directory})
            set (${path} ${directory} PARENT_SCOPE)
        else ()
            message (FATAL_ERROR "Path for directory target not found '${directory}'")
        endif ()
    endif ()
endfunction()

function (_find_in_path glob extensions path result)
    set (values "${${result}}")

    foreach (ext ${extensions})
        file (${glob} file_values ${path}/*.${ext})
        list(APPEND values ${file_values})
    endforeach()

    set (${result} ${values} PARENT_SCOPE)
endfunction()

function (_find_in_dirs glob extensions path subdirs result)
    set (values "${${result}}")

    foreach (dir ${subdirs})
        _find_in_path (${glob} "${extensions}" ${path}/${dir} file_values)
        list(APPEND values ${file_values})
    endforeach()

    set (${result} ${values} PARENT_SCOPE)
endfunction()

function (_add_target_dir_test target_name path)

    # enable loading executables as libraries
    set_target_properties(
        ${target_name}
        PROPERTIES
        ENABLE_EXPORTS TRUE
    )

    # is it "short test target"
    _find_in_path (GLOB "${TREEMAKE_SOURCE_EXT}" ${path} test_source_files)
    list(LENGTH test_source_files test_source_files_count)

    if (test_source_files_count EQUAL 0)
        _get_directories (${path} tests)

        foreach (test ${tests})
            add_executable_dir (
                ${test}
                PRIVATE ${target_name}
            )
        
            get_filename_component (test_name ${test} NAME)
            
            set_target_properties(
                ${test_name}
                PROPERTIES
                RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/test
            )

            add_test (NAME ${test_name} COMMAND ${test_name} WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/test)

        endforeach()
    else ()

        set (test_name ${target_name}_test)
        add_executable (${test_name})

        _add_short_target_dir (
            ${test_name}
            ${path}
            PRIVATE ${target_name}
        )

        set_target_properties(
            ${test_name}
            PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/test
        )

        add_test (NAME ${test_name} COMMAND ${test_name} WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/test)
    endif ()
endfunction ()

function (_add_short_target_dir target_name path)

    # evaluate arguments
    set(options "")
    set(values "")
    set(lists PUBLIC PRIVATE)

    cmake_parse_arguments(LINK "${options}" "${values}" "${lists}" ${ARGN})

    target_link_libraries (${target_name} PUBLIC ${LINK_PUBLIC} PRIVATE ${LINK_PRIVATE})

    _find_in_path (
            GLOB_RECURSE
            "${TREEMAKE_HEADER_EXT}"
            ${path}
            header_files)

    _find_in_path (
            GLOB_RECURSE
            "${TREEMAKE_SOURCE_EXT}"
            ${path}
            source_files)

    target_include_directories (${target_name} PRIVATE ${path})
    target_sources (${target_name} PRIVATE ${header_files} ${source_files})

    # include cmakelists
    if (EXISTS ${path}/CMakeLists.txt)
        _include_for_target (${path}/CMakeLists.txt ${target_name})
    endif()
endfunction ()

function (_add_target_dir target_name path)

    # evaluate arguments
    set(options "")
    set(values "")
    set(lists PUBLIC PRIVATE)

    cmake_parse_arguments(LINK "${options}" "${values}" "${lists}" ${ARGN})

    target_link_libraries (${target_name} PUBLIC ${LINK_PUBLIC} PRIVATE ${LINK_PRIVATE})

    _find_in_dirs (
            GLOB_RECURSE
            "${TREEMAKE_HEADER_EXT}"
            ${path}
            "${TREEMAKE_PUBLIC_DIR}"
            public_headers)

    list(LENGTH public_headers public_header_count)

    if (NOT public_header_count EQUAL 0)
        target_sources (${target_name} PUBLIC ${public_headers})

        foreach (dir ${TREEMAKE_PUBLIC_DIR})
            target_include_directories (${target_name} PUBLIC ${path}/${dir})
        endforeach()
    endif()

    # read source files and private include folder
    _find_in_dirs (
            GLOB_RECURSE
            "${TREEMAKE_HEADER_EXT}"
            ${path}
            "${TREEMAKE_PRIVATE_DIR}"
            source_files)

    _find_in_dirs (
            GLOB_RECURSE
            "${TREEMAKE_SOURCE_EXT}"
            ${path}
            "${TREEMAKE_PRIVATE_DIR}"
            source_files)

    list(LENGTH source_files source_file_count)

    if (NOT source_file_count EQUAL 0)
        target_sources (${target_name} PUBLIC ${source_files})

        foreach (dir ${TREEMAKE_PRIVATE_DIR})
            target_include_directories (${target_name} PUBLIC ${path}/${dir})
        endforeach()
    endif()

    # read submodules
    foreach(dir ${TREEMAKE_MODULE_DIR})
        set (module_path ${path}/${dir})

        if (EXISTS ${module_path})
            _get_directories (${module_path} modules)

            foreach (mod ${modules})
                add_library_dir (${mod} STATIC)
                get_filename_component (mod_name ${mod} NAME)

                target_link_libraries (${target_name} PRIVATE ${mod_name})
            endforeach()
        endif()
    endforeach ()

    # read tests
    if (TREEMAKE_ENABLE_TESTING)
        foreach (dir ${TREEMAKE_TEST_DIR})
            set (test_path ${path}/${dir})

            if (EXISTS ${test_path})
                _add_target_dir_test (${target_name} ${test_path})
            endif()
        endforeach ()
    endif()

    # include cmakelists
    if (EXISTS ${path}/CMakeLists.txt)
        _include_for_target (${path}/CMakeLists.txt ${target_name})
    endif()
endfunction ()

function (add_executable_dir directory)
    _evaluate_path (${directory} path)

    # use path name as target_name
    get_filename_component (target_name ${path} NAME)

    add_executable(${target_name})

    _find_in_path (GLOB "${TREEMAKE_SOURCE_EXT}" ${path} source_files)
    list(LENGTH source_files source_files_count)

    if (source_files_count EQUAL 0)
        _add_target_dir (${target_name} ${path} ${ARGN})
    else ()
        _add_short_target_dir (${target_name} ${path} ${ARGN})
    endif()
endfunction()

function (add_library_dir directory target_type)
    _evaluate_path (${directory} path)

    # use path name as target_name
    get_filename_component (target_name ${path} NAME)

    add_library (${target_name} ${target_type})

    _find_in_path (GLOB "${TREEMAKE_SOURCE_EXT}" ${path} source_files)
    list(LENGTH source_files source_files_count)

    if (source_files_count EQUAL 0)
        _add_target_dir (${target_name} ${path} ${ARGN})
    else ()
        _add_short_target_dir (${target_name} ${path} ${ARGN})
    endif()
endfunction()
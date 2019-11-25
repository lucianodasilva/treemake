cmake_minimum_required (VERSION 3.12)

function (dir_target_name target_name)
    set (${target_name} ${_current_dir_target_name})
endfunction()

function (_include_for_target cmake_file target_name)
    message (STATUS "including file: ${cmake_file}")
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

function (_glob_headers glob path headers)
    file (${glob} values
        ${path}/*.h
        ${path}/*.hpp
        ${path}/*.hxx
    )

    set (${headers} ${values} PARENT_SCOPE)
endfunction()

function (_glob_sources glob path sources)
    file (${glob} values
        ${path}/*.c
        ${path}/*.cpp
        ${path}/*.cxx
    )

    set (${sources} ${values} PARENT_SCOPE)
endfunction()

function (_add_target_dir_test target_name path)
    # enable loading executables as libraries
    set_target_properties(
        ${target_name}
        PROPERTIES
        ENABLE_EXPORTS TRUE
    )

    # is it "short test target"
    _glob_sources (GLOB ${path}/test test_source_files)
    list(LENGTH test_source_files test_source_files_count)

    if (test_source_files_count EQUAL 0)
        _get_directories (${path}/test tests)

        foreach (test ${tests})
            add_executable_dir (
                ${test}
                PUBLIC ${_public_test_link_libraries}
                PRIVATE ${_private_test_link_libraries} ${target_name}
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
            ${path}/test
            PUBLIC ${_public_test_link_libraries}
            PRIVATE ${_private_test_link_libraries} ${target_name}
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

    _glob_headers (GLOB_RECURSE ${path} private_headers)
    _glob_sources (GLOB_RECURSE ${path} source_files)

    target_include_directories (${target_name} PRIVATE ${path})
    target_sources (${target_name} PRIVATE ${private_headers} ${source_files})

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

    # read public include folder
    if (EXISTS ${path}/include)
        set (public_header_path ${path}/include)
        _glob_headers (GLOB_RECURSE ${public_header_path} public_headers)

        target_include_directories (${target_name} PUBLIC ${public_header_path})
        target_sources (${target_name} PUBLIC ${public_headers})
    endif()

    # read source files and private include folder
    if (EXISTS ${path}/source)
        set (source_path ${path}/source)
    elseif(EXISTS ${path}/src)
        set (source_path ${path}/src)
    endif ()

    if (source_path)
        _glob_headers (GLOB_RECURSE ${source_path} private_headers)
        _glob_sources (GLOB_RECURSE ${source_path} source_files)

        target_include_directories (${target_name} PRIVATE ${source_path})
        target_sources (${target_name} PRIVATE ${private_headers} ${source_files})
    endif()

    # read submodules
    if (EXISTS ${path}/modules)
        _get_directories (${path}/modules modules)

        foreach (mod ${modules})
            add_library_dir (${mod} STATIC)
            get_filename_component (mod_name ${mod} NAME)
            
            target_link_libraries (${target_name} PRIVATE ${mod_name})
        endforeach()
    endif()

    # read tests
    if (EXISTS ${path}/test)
        _add_target_dir_test (${target_name} ${path})
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

    _glob_sources (GLOB ${path} source_files)
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

    _glob_sources (GLOB ${path} source_files)
    list(LENGTH source_files source_files_count)

    if (source_files_count EQUAL 0)
        _add_target_dir (${target_name} ${path} ${ARGN})
    else ()
        _add_short_target_dir (${target_name} ${path} ${ARGN})
    endif()
endfunction()
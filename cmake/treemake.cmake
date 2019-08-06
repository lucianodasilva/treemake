cmake_minimum_required (VERSION 3.12)

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

function (_glob_headers path headers)
    file (GLOB_RECURSE values
        ${path}/*.h
        ${path}/*.hpp
        ${path}/*.hxx
    )

    set (${headers} ${values} PARENT_SCOPE)
endfunction()

function (_glob_sources path sources)
    file (GLOB_RECURSE values
        ${path}/*.c
        ${path}/*.cpp
        ${path}/*.cxx
    )

    set (${sources} ${values} PARENT_SCOPE)
endfunction()

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
        _glob_headers (${public_header_path} public_headers)

        target_include_directories (${target_name} PUBLIC ${public_header_path})
        target_sources (${target_name} PUBLIC ${public_headers})
    endif()

    # read source files and private include folder
    if (EXISTS ${path}/source)
        set (source_path ${path}/source)

        _glob_headers (${source_path} private_headers)
        _glob_sources (${source_path} source_files)

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
    if (EXISTS ${path}/tests)

        # enable loading executables as libraries
        set_target_properties(
            ${target_name}
            PROPERTIES
            ENABLE_EXPORTS TRUE
        )

        _get_directories (${path}/tests tests)

        foreach (test ${tests})
            add_executable_dir (
                ${test}
                PUBLIC ${_public_test_link_libraries}
                PRIVATE ${_private_test_link_libraries} ${target_name}
            )
        
            get_filename_component (test_name ${test} NAME)
            add_test (${test_name} ${test_name})
        endforeach()
    endif()

    # include cmakelists
    if (EXISTS ${path}/CMakeLists.txt)
        include (${path}/CMakeLists.txt)
    endif()

endfunction ()

function (add_executable_dir directory)

    _evaluate_path (${directory} path)

    # use path name as target_name
    get_filename_component (target_name ${path} NAME)

    add_executable(${target_name})

    _add_target_dir (${target_name} ${path} ${ARGN})

endfunction()

function (add_library_dir directory target_type)

    _evaluate_path (${directory} path)

    # use path name as target_name
    get_filename_component (target_name ${path} NAME)

    add_library (${target_name} ${target_type})

    _add_target_dir (${target_name} ${path} ${ARGN})

endfunction()

function (set_test_dir_link_libraries)
    set(options "")
    set(values "")
    set(lists PUBLIC PRIVATE)

    cmake_parse_arguments(LINK "${options}" "${values}" "${lists}" ${ARGN})

    set (_public_test_link_libraries ${LINK_PUBLIC} PARENT_SCOPE)
    set (_private_test_link_libraries ${LINK_PRIVATE} PARENT_SCOPE)
endfunction()
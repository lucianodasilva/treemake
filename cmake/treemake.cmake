cmake_minimum_required (VERSION 3.12)

function (_get_directories result path)
    file (GLOB children RELATIVE ${path} ${path}/*)

    set (directories "")

    foreach (child ${children})
        if (IS_DIRECTORY ${path}/${child})
            list(APPEND directories ${path}/${child})
        endif()
    endforeach()

    set (result ${directories})
endfunction()

function (_validate_option key value)
    string (TOUPPER ${key} key)

    # check for values for TARGET_TYPE
    if (${key} STREQUAL "TARGET_TYPE")
        string (TOUPPER ${value} value)

        set (
            AVAILABLE_TARGET_TYPES
            "EXEC"
            "SHARED"
            "STATIC"
        )

        if (NOT value IN_LIST AVAILABLE_TARGET_TYPES)
            message (FATAL_ERROR "Unsupported TARGET_TYPE value: '${value}'")
        endif ()

        set (target_type "${value}" PARENT_SCOPE)
        return()
    endif()

    if (${key} STREQUAL "LIBRARIES")
        separate_arguments(${value})
        list (LENGTH value length)

        if (NOT length EQUAL 0)
            list (APPEND deps ${value})
            set (public_dependencies "${deps}" PARENT_SCOPE)
        endif ()

        return ()
    endif()

    message (FATAL_ERROR "Unsupported option name: ${key}")

endfunction ()

function (add_cmake_dir path)

    # use path name as target_name
    get_filename_component (target_name ${path} NAME)
    message (STATUS "Adding '${path}' as '${target_name}'")

    # setup default variables
    set (target_type "SHARED")

    # read OPTIONS file
    if (EXISTS ${path}/OPTIONS)
        file(STRINGS ${path}/OPTIONS file_content)

        foreach(line ${file_content})
            
            # Strip spaces
            string(STRIP ${line} line)

            # Find variable name
            string(REGEX MATCH "^[^:]+" key ${line})
            # Find the value
            string(REPLACE "${key}:" "" value ${line})

            # bypass invalid lines
            if ("${key}" STREQUAL "" OR "${value}" STREQUAL "")
                continue()
            endif()

            # Strip key spaces
            string(STRIP ${key} key)
            # Strip value spaces
            string(STRIP ${value} value)
            # Validate options
            _validate_option (${key} ${value})

            # Set the variable
            set(${key} "${value}")
        endforeach()
    endif()

    # read public include folder
    if (EXISTS ${path}/include)
        set (public_header_path ${path}/include)

        file (GLOB_RECURSE public_headers
            ${public_header_path}/*.h
            ${public_header_path}/*.hpp
            ${public_header_path}/*.hxx
        )
    endif()

    # read source files and private include folder
    if (EXISTS ${path}/source)
        set (source_path ${path}/source)

        file (GLOB_RECURSE source_files
            ${source_path}/*.c
            ${source_path}/*.cpp
            ${source_path}/*.cxx
        )

        file (GLOB_RECURSE private_headers 
            ${source_path}/*.h
            ${source_path}/*.hpp
            ${source_path}/*.hxx
        )
    endif()

    # read submodules
    if (EXISTS ${path}/modules)
        _get_directories (modules ${path})

        foreach (mod ${modules}})
            add_cmake_dir (${mod})
        endforeach()
    endif()

    # check for source_files
    list (LENGTH source_files length)

    if (length EQUAL 0)
        add_library(${target_name} INTERFACE)

        # add include library paths
        target_include_directories(
            ${target_name}
            INTERFACE
                ${public_header_path}
                ${private_header_path})

        target_sources(
            ${target_name}
            INTERFACE
                ${public_header_path}
                ${private_header_path})
    else()
        # if no target type assume library (shared)
        if (target_type STREQUAL "EXEC")
            add_executable(${target_name} ${source_files} ${private_headers} ${public_headers})
        else ()
            add_library(${target_name} ${target_type} ${source_files} ${private_headers} ${public_headers})
        endif ()

        # add include library paths
        target_include_directories(
            ${target_name}
            PUBLIC
                ${public_header_path}
            PRIVATE
                ${source_path}
        )
    endif ()

    # include cmakelists
    if (EXISTS ${path}/CMakeLists.txt)
        add_subdirectory(${path})
    endif()

    # add dependencies
    target_link_libraries (${target_name}
        PUBLIC ${public_dependencies}
        PRIVATE ${private_dependencies}
        INTERFACE ${interface_dependencies})

endfunction ()
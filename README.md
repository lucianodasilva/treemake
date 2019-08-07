# treemake
CMake Script to automatically (lazily) configure cmake targets from folder layout rules

---

## Root Targets

Root folders amd their respective target types are defined by calling de appropriate function for the required target type.

Both **[executables]** and **[libraries]** are supported as explicit targets by using the following cmake functions:

```cmake
add_executable_dir (<directory> 
        <PUBLIC|PRIVATE> [link_libraries_1...]
        [<PUBLIC|PRIVATE> [link_libraries_2...] ...])

add_library_dir (<directory> [ SHARED | STATIC ]
        <PUBLIC|PRIVATE> [link_libraries_1...]
        [<PUBLIC|PRIVATE> [link_libraries_2...] ...])
```

## Target Folders

All targets are named by their immediately containing folder.

Target folder self configure by following a small set of folder management rules to infer properties about themselves.

### **[include]**
Include folders are interpreted as containing header files mean to be exported to consuming targets.

It is equivalent to calling:
```cmake
target_include_directories (<target> PUBLIC <target_path>/include)
```

### **[source]**
Source folders are interpreted as containing headers and source files to be used internally.

It is equivalent to calling:
```cmake
target_include_directories (<target> PRIVATE <target_path>/source)

target_sources (<target> PRIVATE <files_contained_in_source_folder> )
```

### **[modules]**
When **modules** folders are found, their subdirectories are automatically loaded as static libraries, privately linked to the containing target.

It is equivalent to calling (per contained folder):
```cmake
add_library_dir (<path> STATIC)

target_link_libraries (<containing_target> PRIVATE <added_library>)
```

### **[tests]**
When **tests** folders are found, their subdirectories are automatically loaded as executables, privately linking the containing target.

It is equivalent to calling (per contained folder):
```cmake
add_executable_dir (<path> PRIVATE <containing_targets>)

set_target_properties(
    <target_name>
    PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/tests)

add_test (
    NAME <target_name> 
    COMMAND <target_name>
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/tests)
```
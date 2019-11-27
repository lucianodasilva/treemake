# treemake
CMake Script to automatically (lazily) configure cmake targets from folder layout rules

---

## Root Targets

Root folders and their respective target types are defined by calling de appropriate function for the required target type.

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

Target folder self configure by following a small set of sub folder management rules to infer properties about themselves.

The default folder names **cmake** searches for are editable by overwriting the values of predetermined lists.

### Public Folders **[include]**
Public source folders are interpreted as containing header files to be exported to consuming targets.

It is equivalent to calling:
```cmake
target_include_directories (<target> PUBLIC <target_path>/include)
```

You can change the default or add additional search folders by setting or appending to the **TREEMAKE_PUBLIC_DIR** list.

### Private Folders **[source/src]**
Source folders are interpreted as containing headers and source files to be used internally.

It is equivalent to calling:
```cmake
target_include_directories (<target> PRIVATE <target_path>/source)

target_sources (<target> PRIVATE <files_contained_in_source_folder> )
```

You can change the default or add additional search folders by setting or appending to the **TREEMAKE_PRIVATE_DIR** list.

### Module Libraries **[modules]**
When **modules** folders are found, their subdirectories are automatically loaded as static libraries, privately linked to the containing target.

It is equivalent to calling (per contained folder):
```cmake
add_library_dir (<path> STATIC)

target_link_libraries (<containing_target> PRIVATE <added_library>)
```

You can change the default or add additional search folders by setting or appending to the **TREEMAKE_MODULES_DIR** list.

### **[test]**
When **test** folders are found, their subdirectories are automatically loaded as executables, privately linking the containing target.

It is equivalent to calling (per contained folder):
```cmake
add_executable_dir (<path> PRIVATE <containing_targets>)

set_target_properties(
    <target_name>
    PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/test)

add_test (
    NAME <target_name> 
    COMMAND <target_name>
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/test)
```

You can change the default or add additional search folders by setting or appending to the **TREEMAKE_TEST_DIR** list.

---

## Other Settings

### Disable Test Targets
Test Targets can be disabled by setting the **TREEMAKE_ENABLE_TESTING** list to **OFF**. This option defaults to true.

### Header file Extensions
Header file extensions can be edited by setting or appending **TREEMAKE_HEADER_EXT** list. This list defaults to "h;hpp;hxx".

### Source file Extensions
Source file extensions can be edited by setting or appending **TREEMAKE_SOURCE_EXT** list. This list defaults to "c;cpp;cxx".
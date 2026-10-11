cmake_minimum_required(VERSION 3.19)
project(PlaygroundWasm LANGUAGES CXX)

if(NOT EMSCRIPTEN)
    message(FATAL_ERROR "Configure with emcmake; see README.md")
endif()

set(LUAU_LSP_SOURCE "" CACHE PATH "luau-lsp checkout with submodules")

set(LSP_WERROR OFF CACHE BOOL "" FORCE)
set(LUAU_BUILD_CLI OFF CACHE BOOL "" FORCE)
set(LUAU_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fwasm-exceptions")

add_subdirectory(${LUAU_LSP_SOURCE} luau-lsp EXCLUDE_FROM_ALL)

# No threads in wasm: compile against include/Thread.hpp instead of luau-lsp's pthread wrapper.
set_source_files_properties(${LUAU_LSP_SOURCE}/src/Thread.cpp TARGET_DIRECTORY Luau.LanguageServer PROPERTIES HEADER_FILE_ONLY ON)
target_include_directories(Luau.LanguageServer BEFORE PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

# Type checking (and the VM, for Run Local) decide speed; the rest is optimized for download size.
foreach(TARGET_NAME Luau.LanguageServer Luau.CodeGen Luau.Compiler)
    target_compile_options(${TARGET_NAME} PRIVATE -Os)
endforeach()

set(WASM_LINK_OPTIONS
    -fwasm-exceptions
    -sMODULARIZE=1
    -sENVIRONMENT=worker,node
    -sALLOW_MEMORY_GROWTH=1
    -sSTACK_SIZE=8MB
)

add_executable(luau-lsp src/LspWasm.cpp)
target_link_libraries(luau-lsp PRIVATE Luau.LanguageServer Luau.Analysis)
target_link_options(luau-lsp PRIVATE ${WASM_LINK_OPTIONS}
    -sINITIAL_MEMORY=128MB
    -sEXPORT_NAME=createLuauLsp
    -sEXPORTED_FUNCTIONS=_lsp_start,_lsp_send,_lsp_set_imports,_lsp_load_documentation,_malloc,_free
    -sEXPORTED_RUNTIME_METHODS=FS,UTF8ToString,stringToNewUTF8
)

add_executable(luau-run src/RunWasm.cpp)
target_link_libraries(luau-run PRIVATE Luau.Compiler Luau.VM)
target_link_options(luau-run PRIVATE ${WASM_LINK_OPTIONS}
    -sEXPORT_NAME=createLuauRun
    -sEXPORTED_FUNCTIONS=_main,_run_set_flag,_run_reset,_run_add_module,_run_start,_run_step,_malloc,_free
    -sEXPORTED_RUNTIME_METHODS=UTF8ToString,stringToNewUTF8
)

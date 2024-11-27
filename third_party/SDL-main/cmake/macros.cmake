macro(add_to_alloptions _NEWNAME)
  list(APPEND ALLOPTIONS ${_NEWNAME})
  string(LENGTH ${_NEWNAME} _SLEN)
  if(${LONGESTOPTIONNAME} LESS ${_SLEN})
    set(LONGESTOPTIONNAME ${_SLEN})
  endif()
endmacro()

macro(set_option _NAME _DESC)
  add_to_alloptions(${_NAME})
  if(${ARGC} EQUAL 3)
    set(_DEFLT ${ARGV2})
  else()
    set(_DEFLT OFF)
  endif()
  option(${_NAME} ${_DESC} ${_DEFLT})
endmacro()

macro(dep_option _NAME _DESC _DEFLT _DEPTEST _FAILDFLT)
  add_to_alloptions("${_NAME}")
  cmake_dependent_option("${_NAME}" "${_DESC}" "${_DEFLT}" "${_DEPTEST}" "${_FAILDFLT}")
endmacro()

macro(option_string _NAME _DESC _VALUE)
  add_to_alloptions(${_NAME})
  set(${_NAME} ${_VALUE} CACHE STRING "${_DESC}")
  set(HAVE_${_NAME} ${_VALUE})
ENDMACRO()

# Message Output
macro(message_warn _TEXT)
  message(WARNING "${_TEXT}")
endmacro()

macro(message_error _TEXT)
  message(FATAL_ERROR "*** ERROR: ${_TEXT}")
endmacro()

macro(message_bool_option _NAME _VALUE)
  set(_PAD "\t")
  if(${ARGC} EQUAL 3)
    set(_PAD ${ARGV2})
  endif()
  if(${_VALUE})
    message(STATUS "  ${_NAME}:${_PAD}ON")
  else()
    message(STATUS "  ${_NAME}:${_PAD}OFF")
  endif()
endmacro()

macro(message_tested_option _NAME)
  set(_REQVALUE ${${_NAME}})
  set(_PAD " ")
  if(${ARGC} EQUAL 2)
    set(_PAD ${ARGV1})
  endif()
  string(SUBSTRING "${_NAME}" 0 4 _NAMESTART)
  if(_NAMESTART STREQUAL "SDL_")
    string(SUBSTRING "${_NAME}" 4 -1 _STRIPPEDNAME)
  else()
    set(_STRIPPEDNAME "${_NAME}")
  endif()
  if(NOT HAVE_${_STRIPPEDNAME})
    set(HAVE_${_STRIPPEDNAME} OFF)
  elseif("${HAVE_${_STRIPPEDNAME}}" MATCHES "1|TRUE|YES|Y")
    set(HAVE_${_STRIPPEDNAME} ON)
  endif()
  message(STATUS "  ${_NAME}${_PAD}(Wanted: ${_REQVALUE}): ${HAVE_${_STRIPPEDNAME}}")
endmacro()

function(listtostr LIST OUTPUT)
  if(${ARGC} EQUAL 3)
    # prefix for each element
    set(LPREFIX ${ARGV2})
  else()
    set(LPREFIX "")
  endif()
  # Do not use string(REPLACE ";" " ") here to avoid messing up list entries
  set(res)
  foreach(ITEM ${${LIST}})
    if(ITEM MATCHES "^SHELL:")
      string(SUBSTRING "${ITEM}" 6 -1 ITEM)
    endif()
    if(ITEM)
      set(res "${res} ${LPREFIX}${ITEM}")
    endif()
  endforeach()
  string(STRIP "${res}" res)
  set(${OUTPUT} "${res}" PARENT_SCOPE)
endfunction()

function(find_stringlength_longest_item inList outLength)
  set(maxLength 0)
  foreach(item IN LISTS ${inList})
    string(LENGTH "${item}" slen)
    if(slen GREATER maxLength)
      set(maxLength ${slen})
    endif()
  endforeach()
  set("${outLength}" ${maxLength} PARENT_SCOPE)
endfunction()

function(message_dictlist inList)
  find_stringlength_longest_item(${inList} maxLength)
  foreach(name IN LISTS ${inList})
    # Get the padding
    string(LENGTH ${name} nameLength)
    math(EXPR padLength "(${maxLength} + 1) - ${nameLength}")
    string(RANDOM LENGTH ${padLength} ALPHABET " " padding)
    message_tested_option(${name} ${padding})
  endforeach()
endfunction()

if(CMAKE_VERSION VERSION_LESS 3.16.0 OR SDL3_SUBPROJECT)
  # - CMake versions <3.16 do not support the OBJC language
  # - When SDL is built as a subproject and when the main project does not enable OBJC,
  #   CMake fails due to missing internal CMake variables (CMAKE_OBJC_COMPILE_OBJECT)
  #   (reproduced with CMake 3.24.2)
  macro(CHECK_OBJC_SOURCE_COMPILES SOURCE VAR)
    set(PREV_REQUIRED_DEFS "${CMAKE_REQUIRED_DEFINITIONS}")
    set(CMAKE_REQUIRED_DEFINITIONS "-x objective-c ${PREV_REQUIRED_DEFS}")
    CHECK_C_SOURCE_COMPILES("${SOURCE}" ${VAR})
    set(CMAKE_REQUIRED_DEFINITIONS "${PREV_REQUIRED_DEFS}")
  endmacro()
else()
  include(CheckOBJCSourceCompiles)
  if (APPLE)
      enable_language(OBJC)
  endif()
endif()

if(CMAKE_VERSION VERSION_LESS 3.18)
  function(check_linker_flag LANG FLAG VAR)
    cmake_push_check_state()
    list(APPEND CMAKE_REQUIRED_LINK_OPTIONS ${FLAG} )
    if(LANG STREQUAL "C")
      include(CheckCSourceCompiles)
      check_c_source_compiles("int main(int argc,char*argv[]){(void)argc;(void)argv;return 0;}" ${VAR} FAIL_REGEX "warning")
    elseif(LANG STREQUAL "CXX")
      include(CheckCXXSourceCompiles)
      check_cxx_source_compiles("int main(int argc,char*argv[]){(void)argc;(void)argv;return 0;}" ${VAR} FAIL_REGEX "warning")
    else()
      message(FATAL_ERROR "Unsupported language: ${LANG}")
    endif()
    cmake_pop_check_state()
  endfunction()
else()
  cmake_policy(SET CMP0057 NEW)  # Support new if() IN_LIST operator. (used inside check_linker_flag, used in CMake 3.18)
  include(CheckLinkerFlag)
endif()

if(APPLE)
  check_language(OBJC)
  if(NOT CMAKE_OBJC_COMPILER)
    message(WARNING "Cannot find working OBJC compiler.")
  endif()
endif()

if(CMAKE_VERSION VERSION_LESS 3.13.0)
  macro(target_link_directories _TARGET _SCOPE)
    link_directories(${ARGN})
  endmacro()
endif()

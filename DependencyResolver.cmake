#-----------------------------------------------------------------------#

function(add_and_resolve_package_dependencies BIN_DIR)

  # Only run once - for the main/starting package
  # TODO: Don't require top-level source folder, set something in cache instead:
  #       DependencyResolver package(s) can be included by non-DR packages.
  if(NOT ${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_SOURCE_DIR})
    return()
  endif()

  set(TPL_COUNT 0)
  get_package_info(${CMAKE_CURRENT_SOURCE_DIR} TPL_COUNT MAIN_PACKAGE_NAME C D)

  if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
    message("")
    message("#")
    message("# Dependency graph:")
  endif()
  set(VISITED "")
  set(COMPONENTS "{}")
  set(DEPENDENCIES "{}")
  set(PCKG_PARENTS "{}")
  set(SRC_DIRS "")
  get_dependency_graph(${CMAKE_CURRENT_SOURCE_DIR}
    VISITED SRC_DIRS COMPONENTS DEPENDENCIES PCKG_PARENTS TPL_COUNT
    "" "${MAIN_PACKAGE_NAME}" ON)
  if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
    message("#")
    message("")
  endif()

  show_package_list("${VISITED}" "${SRC_DIRS}" "${COMPONENTS}" "${DEPENDENCIES}")

  foreach(NAME SRC_DIR IN ZIP_LISTS VISITED SRC_DIRS)
    if(NOT "${SRC_DIR}" STREQUAL "${CMAKE_CURRENT_SOURCE_DIR}")
      set(PACKAGE_NAME ${NAME})
      string(JSON CS GET ${COMPONENTS} ${NAME})
      parse_component_set(${CS} PACKAGE_COMPONENTS)
      string(JSON DS GET ${DEPENDENCIES} ${NAME})
      parse_component_set(${DS} PACKAGE_DEPENDENCIES)

      make_package_info_line(MSG "${PACKAGE_NAME}" "${SRC_DIR}" "${PACKAGE_COMPONENTS}" "${PACKAGE_DEPENDENCIES}")
      message(STATUS "-----------------------------------------------------------")
      message(STATUS "Configuring package ${MSG}")
      message(STATUS "")

      add_subdirectory("${SRC_DIR}" "${BIN_DIR}/${NAME}")
    endif()
  endforeach()

  # Set main package info (for consistency)
  set(PACKAGE_NAME ${MAIN_PACKAGE_NAME})
  string(JSON CS GET ${COMPONENTS} ${NAME})
  parse_component_set(${CS} PACKAGE_COMPONENTS)
  string(JSON DS GET ${DEPENDENCIES} ${NAME})
  parse_component_set(${DS} PACKAGE_DEPENDENCIES)
  set(PACKAGE_NAME "${PACKAGE_NAME}" PARENT_SCOPE)
  set(PACKAGE_COMPONENTS "${PACKAGE_COMPONENTS}" PARENT_SCOPE)
  set(PACKAGE_DEPENDENCIES "${PACKAGE_DEPENDENCIES}" PARENT_SCOPE)

  make_package_info_line(MSG "${PACKAGE_NAME}" "${SRC_DIR}" "${PACKAGE_COMPONENTS}" "${PACKAGE_DEPENDENCIES}")
  message(STATUS "Finished configuration of upstream packages")
  message(STATUS "-----------------------------------------------------------")
  message(STATUS "Configuring package ${MSG}")
  message(STATUS "")

endfunction()
#-----------------------------------------------------------------------#
#
# Visits packages recursively (going upstream from the main packages)
#
function(get_dependency_graph PCKG_SRC_DIR INOUT_VISITED_PACKAGES INOUT_PCKG_SRCDIRS
                              INOUT_PCKG_COMPONENTS INOUT_PCKG_DEPENDENCIES INOUT_PCKG_PARENTS INOUT_TPL_COUNT
                              PARENTS PACKAGE_NAME FORCE)
  set(VISITED_PACKAGES ${${INOUT_VISITED_PACKAGES}})
  set(PCKG_SRCDIRS ${${INOUT_PCKG_SRCDIRS}})
  set(PCKG_COMPONENTS ${${INOUT_PCKG_COMPONENTS}})
  set(PCKG_DEPENDENCIES ${${INOUT_PCKG_DEPENDENCIES}})
  set(PCKG_PARENTS ${${INOUT_PCKG_PARENTS}})
  set(TPL_COUNT ${${INOUT_TPL_COUNT}})

  # Fetch static package info (structure and dependencies)
  get_package_info(${PCKG_SRC_DIR} TPL_COUNT NAME COMPONENTS DEPENDENCIES)

  # Fetch dynamic package config (active elements derived from build options)
  get_package_config(${PCKG_SRC_DIR} ENABLED_COMPONENTS ENABLED_DEPENDENCIES)

  # Update components list
  add_components(PCKG_COMPONENTS ${NAME} "${ENABLED_COMPONENTS}" ACTIVE_COMPONENTS)
  add_components(PCKG_DEPENDENCIES ${NAME} "${ENABLED_DEPENDENCIES}" ACTIVE_DEPENDENCIES)

  # Skip already visited packages
  # NOTE: this is executed after add_components() has chance
  #       to update component list and force revisit
  list(FIND VISITED_PACKAGES ${NAME} SKIP)
  if (FORCE OR SKIP EQUAL -1)

    if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
      if(FORCE AND NOT SKIP EQUAL -1)
        message("#  Package ${NAME} in ${PCKG_SRC_DIR} (forced)")
      else()
        message("#  Package ${NAME} in ${PCKG_SRC_DIR}")
      endif()
      message("#      parents = [${PARENTS}], visited = [${VISITED_PACKAGES}]")
      message("#      components = [${ACTIVE_COMPONENTS}]")
      message("#      dependencies = [${ACTIVE_DEPENDENCIES}]")
    endif()

    # Add current package to visited
    add_visited_package(VISITED_PACKAGES PCKG_SRCDIRS ${PCKG_PARENTS} ${NAME} ${PCKG_SRC_DIR})
    list(APPEND PARENTS ${NAME}) # PARENTS = current stack of packages visited in depth-first order
    # Visit all enabled dependencies (recursively)
    visit_active_dependencies(
        VISITED_PACKAGES PCKG_SRCDIRS PCKG_COMPONENTS PCKG_DEPENDENCIES PCKG_PARENTS
        "${PARENTS}" "${NAME}"
        "${COMPONENTS}" "${ACTIVE_COMPONENTS}"
        "${DEPENDENCIES}" "${ACTIVE_DEPENDENCIES}")
  else()
    if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
      message("#  Skipping package ${NAME} (already visited)")
    endif()
  endif()

  # Set output variables
  set(${INOUT_VISITED_PACKAGES} ${VISITED_PACKAGES} PARENT_SCOPE)
  set(${INOUT_PCKG_SRCDIRS} ${PCKG_SRCDIRS} PARENT_SCOPE)
  set(${INOUT_PCKG_COMPONENTS} ${PCKG_COMPONENTS} PARENT_SCOPE)
  set(${INOUT_PCKG_DEPENDENCIES} ${PCKG_DEPENDENCIES} PARENT_SCOPE)
  set(${INOUT_PCKG_PARENTS} ${PCKG_PARENTS} PARENT_SCOPE)
  set(${INOUT_TPL_COUNT} ${TPL_COUNT} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------#

function(visit_active_dependencies INOUT_VISITED_PACKAGES INOUT_PCKG_SRCDIRS
                                   INOUT_PCKG_COMPONENTS INOUT_PCKG_DEPENDENCIES INOUT_PCKG_PARENTS
                                   PARENTS PACKAGE_NAME
                                   COMPONENTS ACTIVE_COMPONENTS
                                   DEPENDENCIES ACTIVE_DEPENDENCIES)

  set(VISITED_PACKAGES ${${INOUT_VISITED_PACKAGES}})
  set(PCKG_SRCDIRS ${${INOUT_PCKG_SRCDIRS}})
  set(PCKG_COMPONENTS ${${INOUT_PCKG_COMPONENTS}})
  set(PCKG_DEPENDENCIES ${${INOUT_PCKG_DEPENDENCIES}})
  set(PCKG_PARENTS ${${INOUT_PCKG_PARENTS}})
  set(TPL_COUNT ${${INOUT_TPL_COUNT}})

  # Visit package dependencies
  string(JSON N LENGTH ${DEPENDENCIES})
  if(N GREATER 0)
    if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
      message("#  Checking ${PACKAGE_NAME} package dependencies:")
    endif()
    math(EXPR N "${N} - 1")
    foreach(I RANGE ${N})
      string(JSON DEP GET ${DEPENDENCIES} ${I})
      if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
        string(JSON DEP_NAME GET ${DEP} name)
        message("#  ${PACKAGE_NAME} -> ${DEP_NAME} ?")
      endif()
      visit_active_dependency(
          VISITED_PACKAGES PCKG_SRCDIRS
          PCKG_COMPONENTS PCKG_DEPENDENCIES PCKG_PARENTS TPL_COUNT
          "${PARENTS}" "${PACKAGE_NAME}"
          "${ACTIVE_DEPENDENCIES}" ${DEP})
    endforeach()
  endif()

  # Visit component dependencies
  string(JSON N LENGTH ${COMPONENTS})
  if(N GREATER 0)
    if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
      message("#  Checking ${PACKAGE_NAME} component dependencies:")
    endif()
    math(EXPR N "${N} - 1")
    foreach(I RANGE ${N})
      # fetch component info
      string(JSON COMPONENT GET ${COMPONENTS} ${I})
      string(JSON CNAME GET ${COMPONENT} name)
      string(JSON OPTIONAL GET ${COMPONENT} optional)
      if(OPTIONAL) # check if optional component is activated
        list(FIND ACTIVE_COMPONENTS ${CNAME} INDEX)
        if(INDEX EQUAL -1)
          continue()
        endif()
      endif()
      string(JSON CDEPS ERROR_VARIABLE JSON_ERR GET ${COMPONENT} dependencies)
      if(NOT JSON_ERR STREQUAL "NOTFOUND")
        set(CDEPS "[]")
      endif()
      string(JSON M LENGTH ${CDEPS})
      if(M GREATER 0)
        math(EXPR M "${M} - 1")
        foreach(I RANGE ${M})
          string(JSON DEP GET ${CDEPS} ${I})
          string(JSON DEP_NAME GET ${DEP} name)
          if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
            message("#  ${PACKAGE_NAME}.${CNAME} -> ${DEP_NAME} ?")
          endif()
          visit_active_dependency(
            VISITED_PACKAGES PCKG_SRCDIRS
            PCKG_COMPONENTS PCKG_DEPENDENCIES
            PCKG_PARENTS TPL_COUNT
            "${PARENTS}" "${PACKAGE_NAME}"
            "${ACTIVE_DEPENDENCIES}" ${DEP})
          # Enable component dependency in package dependencies
          if(NOT PACKAGE_NAME STREQUAL ${DEP_NAME})
            add_components(PCKG_DEPENDENCIES ${PACKAGE_NAME} "${DEP_NAME}" UPDATED)
          endif()
        endforeach()
      endif()
    endforeach()
  endif()

  # Set output variables
  set(${INOUT_VISITED_PACKAGES} ${VISITED_PACKAGES} PARENT_SCOPE)
  set(${INOUT_PCKG_SRCDIRS} ${PCKG_SRCDIRS} PARENT_SCOPE)
  set(${INOUT_PCKG_COMPONENTS} ${PCKG_COMPONENTS} PARENT_SCOPE)
  set(${INOUT_PCKG_DEPENDENCIES} ${PCKG_DEPENDENCIES} PARENT_SCOPE)
  set(${INOUT_PCKG_PARENTS} ${PCKG_PARENTS} PARENT_SCOPE)
  set(${INOUT_TPL_COUNT} ${TPL_COUNT} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------#

function(visit_active_dependency INOUT_VISITED_PACKAGES INOUT_PCKG_SRCDIRS
                                 INOUT_PCKG_COMPONENTS INOUT_PCKG_DEPENDENCIES
                                 INOUT_PCKG_PARENTS INOUT_TPL_COUNT
                                 PARENTS PACKAGE_NAME ACTIVE_DEPENDENCIES DEPENDENCY)
  set(VISITED_PACKAGES ${${INOUT_VISITED_PACKAGES}})
  set(PCKG_SRCDIRS ${${INOUT_PCKG_SRCDIRS}})
  set(PCKG_COMPONENTS ${${INOUT_PCKG_COMPONENTS}})
  set(PCKG_DEPENDENCIES ${${INOUT_PCKG_DEPENDENCIES}})
  set(PCKG_PARENTS ${${INOUT_PCKG_PARENTS}})
  set(TPL_COUNT ${${INOUT_TPL_COUNT}})

  string(JSON DEP_NAME GET ${DEPENDENCY} name)
  add_components(PCKG_PARENTS ${DEP_NAME} ${PACKAGE_NAME} UPDATED)

  # Determine component list (default to ALL required)
  string(JSON REQUIRED_COMPONENTS ERROR_VARIABLE JSON_ERR GET ${DEPENDENCY} components_required)
  if(NOT JSON_ERR STREQUAL "NOTFOUND")
    set(REQUIRED_COMPONENTS "[]")
  endif()
  string(JSON OPTIONAL_COMPONENTS ERROR_VARIABLE JSON_ERR GET ${DEPENDENCY} components_optional)
  if(NOT JSON_ERR STREQUAL "NOTFOUND")
    set(OPTIONAL_COMPONENTS "[]")
  endif()

  # Add all enabled components
  if(${REQUIRED_COMPONENTS} STREQUAL "*")
    set(DEP_COMPONENTS_LIST "*")
  else()
    parse_json_list(${REQUIRED_COMPONENTS} DEP_COMPONENTS_LIST)
    list(FIND ACTIVE_DEPENDENCIES ${DEP_NAME} INDEX)
    if(INDEX GREATER -1)
      set(ALL_ENABLED ON)
    else()
      set(ALL_ENABLED OFF)
    endif()
    if(OPTIONAL_COMPONENTS STREQUAL "*")
      if(ALL_ENABLED)
        set(DEP_COMPONENTS_LIST "*") # all components are optional and enabled
      else()
        # Add all components listed in active dependencies
        foreach(A IN LISTS ACTIVE_DEPENDENCIES)
          string(REGEX MATCH "^${DEP_NAME}\." MATCH ${A})
          if(MATCH)
            string(LENGTH ${MATCH} OFFSET)
            string(SUBSTRING ${A} ${OFFSET} -1 C)
            list(APPEND DEP_COMPONENTS_LIST ${C})
          endif()
        endforeach()
      endif()
    else()
      parse_json_list(${OPTIONAL_COMPONENTS} OPTIONAL_COMPONENTS)
      foreach(C IN LISTS OPTIONAL_COMPONENTS)
        if(ALL_ENABLED)
          list(APPEND DEP_COMPONENTS_LIST ${C})
        else()
          list(FIND ACTIVE_DEPENDENCIES "${DEP_NAME}.${C}" INDEX)
          if(INDEX GREATER -1)
            list(APPEND DEP_COMPONENTS_LIST ${C})
          endif()
        endif()
      endforeach()
    endif()
  endif()

  set(SKIP FALSE)

  # Check if package needs to be revisited because of component list change
  # NOTE: do it whenever package is skipped by this dependency - it can be required by some other
  string(JSON PREV ERROR_VARIABLE JSON_ERR GET ${PCKG_COMPONENTS} ${DEP_NAME})
  if(NOT JSON_ERR STREQUAL "NOTFOUND")
    set(PREV "{}")
  endif()
  parse_component_set(${PREV} PREV)
  add_components(PCKG_COMPONENTS ${DEP_NAME} "${DEP_COMPONENTS_LIST}" UPDATED)
  set(FORCE OFF)
  if(UPDATED)

    # Revisit package if component set has changed
    if(NOT PREV STREQUAL UPDATED)
      list(FIND VISITED_PACKAGES ${DEP_NAME} INDEX)
      if(INDEX GREATER -1)
        if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
          message("#  Will revisit package ${DEP_NAME}, components updated")
          message("#      from: [${PREV}]")
          message("#      to:   [${UPDATED}]")
        endif()
        set(FORCE ON)
      elseif(PREV)
        message(FATAL_ERROR "Internal: unexpected components: [${PREV}]")
      endif()
    endif()

  else()
    ## Skip packages with no required components
    ## NOTE: package without components will still be visited with UPDATED="*"
    ##if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
    ##  message("#  Skipping package ${DEP_NAME} (no components required)")
    ##endif()
    ##set(SKIP TRUE)
  endif()

  # Skip disabled optional dependencies
  string(JSON OPTIONAL ERROR_VARIABLE JSON_ERR GET ${DEP} optional)
  if((JSON_ERR STREQUAL "NOTFOUND") AND OPTIONAL)
    list(FIND ACTIVE_DEPENDENCIES ${DEP_NAME} INDEX)
    if(INDEX EQUAL -1)
      if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
        message("#  Skipping package ${DEP_NAME} (disabled optional dependency of ${NAME})")
      endif()
      set(SKIP TRUE)
    endif()
  endif()

  # Visit upstream package
  if(NOT SKIP)
    string(JSON DEP_DIR GET ${DEP} source_dir)
    if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
      message("#  ${PACKAGE_NAME} -> ${DEP_NAME}: [${UPDATED}]")
    endif()
    get_dependency_graph(
      ${DEP_DIR}
      VISITED_PACKAGES PCKG_SRCDIRS PCKG_COMPONENTS PCKG_DEPENDENCIES PCKG_PARENTS TPL_COUNT
      "${PARENTS}" "${PACKAGE_NAME}" "${FORCE}")
  endif()

  set(${INOUT_VISITED_PACKAGES} ${VISITED_PACKAGES} PARENT_SCOPE)
  set(${INOUT_PCKG_SRCDIRS} ${PCKG_SRCDIRS} PARENT_SCOPE)
  set(${INOUT_PCKG_COMPONENTS} ${PCKG_COMPONENTS} PARENT_SCOPE)
  set(${INOUT_PCKG_DEPENDENCIES} ${PCKG_DEPENDENCIES} PARENT_SCOPE)
  set(${INOUT_PCKG_PARENTS} ${PCKG_PARENTS} PARENT_SCOPE)
  set(${INOUT_TPL_COUNT} ${TPL_COUNT} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------#
#
# get_package_info(SRC_DIR NAME DEPS)
#
# In:
#    * SRC_DIR: package top level directory
# Out:
#    * OUT_NAME: package name
#    * OUT_COMPONENTS: list of directories containing upstream packages
#    * OUT_DEPENDENCIES
#
function(get_package_info SRC_DIR INOUT_TPL_COUNT OUT_NAME OUT_COMPONENTS OUT_DEPENDENCIES)
  set(TPL_COUNT ${${INOUT_TPL_COUNT}})

  # Check if cmake/PackageInfo.json exists
  set(ENTRY ___FILE_EXISTS_${SRC_DIR})
  set(PATH ${SRC_DIR}/cmake/PackageInfo.json)
  find_file(${ENTRY} PackageInfo.json ${SRC_DIR}/cmake NO_DEFAULT_PATH
      NO_PACKAGE_ROOT_PATH NO_CMAKE_PATH NO_CMAKE_ENVIRONMENT_PATH
      NO_SYSTEM_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH NO_CMAKE_FIND_ROOT_PATH)
  if(${ENTRY} STREQUAL "${ENTRY}-NOTFOUND")
    math(EXPR TPL_COUNT "${TPL_COUNT} + 1")
    set(NAME "__TPL${TPL_COUNT}")
    if(DEPENDENCY_RESOLVER_DEBUG_SHOW_DIAGNOSTICS)
      message("#  Found ${NAME} in ${SRC_DIR}")
    endif()
    set(${OUT_NAME} ${NAME} PARENT_SCOPE)
    set(${OUT_COMPONENTS} "[]" PARENT_SCOPE)
    set(${OUT_DEPENDENCIES} "[]" PARENT_SCOPE)
    set(${INOUT_TPL_COUNT} ${TPL_COUNT} PARENT_SCOPE)
    return()
  endif()

  # Read JSON file
  file(READ ${PATH} ROOT)

  # Get current package name
  string(JSON NAME GET "${ROOT}" name)
  set(${OUT_NAME} ${NAME} PARENT_SCOPE)

  # Get components
  string(JSON COMPONENTS ERROR_VARIABLE JSON_ERR GET ${ROOT} components)
  if(NOT JSON_ERR STREQUAL "NOTFOUND")
    set(COMPONENTS "[]")
  endif()
  set(${OUT_COMPONENTS} "${COMPONENTS}" PARENT_SCOPE)

  # Get dependencies for active components
  string(JSON DEPS ERROR_VARIABLE JSON_ERR GET ${ROOT} dependencies)
  if(NOT JSON_ERR STREQUAL "NOTFOUND")
    set(DEPS "[]")
  endif()
  set(${OUT_DEPENDENCIES} "${DEPS}" PARENT_SCOPE)

  set(${INOUT_TPL_COUNT} ${TPL_COUNT} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------#
#
# get_package_config(SRC_DIR ENABLED COMPONENTS ENABLED_DEPENDENCIES)
#
# In:
#    * SRC_DIR: package top level directory
# Out:
#    * OUT_ENABLED: is this package enabled (ON/OFF)
#    * OUT_COMPONENTS: list of enabled components ("*" = all)
#    * OUT_ENABLED_DEPENDENCIES: list of enabled dependencies
#
function(get_package_config SRC_DIR OUT_COMPONENTS OUT_ENABLED_DEPENDENCIES)
  # Set defaults
  set(PACKAGE_COMPONENTS "")
  set(PACKAGE_DEPENDENCIES "")
  # Load dynamic config file
  include(${SRC_DIR}/cmake/GetPackageComponents.cmake OPTIONAL)
  # Set output variables
  set(${OUT_COMPONENTS} ${PACKAGE_COMPONENTS} PARENT_SCOPE)
  set(${OUT_ENABLED_DEPENDENCIES} ${PACKAGE_DEPENDENCIES} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------#
#
# This functions inserts package NAME into the list of INOUT_VISITED_PACKAGES
# keeping topological order based on PARENTS.
#
function(add_visited_package INOUT_VISITED_PACKAGES INOUT_PCKG_SRCDIRS
                            PCKG_PARENTS NAME SRC_DIR)
  set(VISITED_PACKAGES ${${INOUT_VISITED_PACKAGES}})
  set(PCKG_SRCDIRS ${${INOUT_PCKG_SRCDIRS}})

  # Fetch package parents
  string(JSON PARENTS ERROR_VARIABLE JSON_ERR GET ${PCKG_PARENTS} ${NAME})
  if(NOT JSON_ERR STREQUAL "NOTFOUND")
    set(PARENTS "{}")
  endif()
  parse_component_set(${PARENTS} PARENTS)

  # Place package before all it's parents
  list(FIND VISITED_PACKAGES ${NAME} INDEX)
  if(INDEX GREATER -1)
    return() # already on the list (forced revisit)
  endif()
  list(LENGTH VISITED_PACKAGES INDEX)
  foreach(P IN LISTS PARENTS)
    list(FIND VISITED_PACKAGES ${P} I)
    if(NOT I EQUAL -1 AND I LESS INDEX)
      set(INDEX ${I})
    endif()
  endforeach()
  list(INSERT VISITED_PACKAGES ${INDEX} ${NAME})
  list(INSERT PCKG_SRCDIRS ${INDEX} ${SRC_DIR})

  # Set outputs
  set(${INOUT_VISITED_PACKAGES} ${VISITED_PACKAGES} PARENT_SCOPE)
  set(${INOUT_PCKG_SRCDIRS} ${PCKG_SRCDIRS} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------#

function(parse_json_list DATA OUT_LIST)
  set(OUT "")
  string(JSON N LENGTH ${DATA})
  if(N GREATER 0)
    math(EXPR N "${N} - 1")
    foreach(I RANGE ${N})
      string(JSON ITEM GET ${DATA} ${I})
      list(APPEND OUT ${ITEM})
    endforeach()
  endif()
  set(${OUT_LIST} "${OUT}" PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------#

function(parse_component_set DATA OUT_LIST)
  if(${DATA} STREQUAL "*")
    set(${OUT_LIST} "*" PARENT_SCOPE)
    return()
  endif()
  set(OUT "")
  string(JSON N LENGTH ${DATA})
  if(N GREATER 0)
    math(EXPR N "${N} - 1")
    foreach(I RANGE ${N})
      string(JSON ITEM MEMBER ${DATA} ${I})
      list(APPEND OUT ${ITEM})
    endforeach()
  endif()
  set(${OUT_LIST} "${OUT}" PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------#

function(add_components INOUT_PCKG_COMPONENTS DEP_NAME NEW_COMPONENTS OUT_COMPONENTS)
  set(PCKG_COMPONENTS ${${INOUT_PCKG_COMPONENTS}})
  set(COMPONENTS "")

  # message(=============================== Before)
  # message(${PCKG_COMPONENTS})

  if(NEW_COMPONENTS STREQUAL "*") # all components
    set(UNION "\"*\"")
    set(COMPONENTS "*")
    string(JSON PCKG_COMPONENTS SET ${PCKG_COMPONENTS} ${DEP_NAME} "\"*\"") # why \"*\" (string value) does not work ?
  else()
    string(JSON UNION ERROR_VARIABLE JSON_ERR GET ${PCKG_COMPONENTS} ${DEP_NAME})
    if(NOT JSON_ERR STREQUAL "NOTFOUND")
      set(UNION "{}")
    endif()
    if(UNION STREQUAL "*") # keep all components
      set(COMPONENTS "*")
    else()

      # Merge NEW_COMPONENTS into UNION
      foreach(CNAME IN LISTS NEW_COMPONENTS)
        string(JSON VAL ERROR_VARIABLE JSON_ERR GET ${UNION} ${CNAME})
        if(NOT JSON_ERR STREQUAL "NOTFOUND")
          string(JSON UNION SET ${UNION} ${CNAME} true)
        endif()
      endforeach()

      # Update package component list
      string(JSON PCKG_COMPONENTS SET ${PCKG_COMPONENTS} ${DEP_NAME} ${UNION})

      # Fetch updated components as plain list
      parse_component_set(${UNION} COMPONENTS)

    endif()
  endif()

  # message(=============================== After:)
  # message(${PCKG_COMPONENTS})
  # message(===============================)

  set(${INOUT_PCKG_COMPONENTS} ${PCKG_COMPONENTS} PARENT_SCOPE)
  set(${OUT_COMPONENTS} ${COMPONENTS} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------#

function(show_package_list VISITED SRC_DIRS COMPONENTS DEPENDENCIES)
  message("")
  message(STATUS "")
  message(STATUS "Configuring packages:")
  foreach(NAME SRC_DIR IN ZIP_LISTS VISITED SRC_DIRS)
    set(PACKAGE_NAME ${NAME})
    string(JSON CS GET ${COMPONENTS} ${NAME})
    parse_component_set(${CS} PACKAGE_COMPONENTS)
    string(JSON DS GET ${DEPENDENCIES} ${NAME})
    parse_component_set(${DS} PACKAGE_DEPENDENCIES)
    make_package_info_line(MSG "${NAME}" "${SRC_DIR}" "${PACKAGE_COMPONENTS}" "${PACKAGE_DEPENDENCIES}")
    message(STATUS " - ${MSG}")
  endforeach()
  message(STATUS "")
  message("")
endfunction()

function(make_package_info_line LINE NAME SRC_DIR PACKAGE_COMPONENTS PACKAGE_DEPENDENCIES)
  set(MSG "${NAME} (from ${SRC_DIR})")
  if(PACKAGE_COMPONENTS STREQUAL "*")
    string(APPEND MSG "\n      components: ALL")
  elseif(PACKAGE_COMPONENTS STREQUAL "")
    #string(APPEND MSG "\n      components: ---")
  else()
    string(APPEND MSG "\n      components: ${PACKAGE_COMPONENTS}")
  endif()
  if(PACKAGE_DEPENDENCIES)
    string(APPEND MSG "\n      dependencies: ${PACKAGE_DEPENDENCIES}")
  else()
    #string(APPEND MSG "\n      dependencies: ---")
  endif()
  set(${LINE} ${MSG} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------#

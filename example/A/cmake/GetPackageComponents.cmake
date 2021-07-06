#
# This is DependencyResolver dynamic configuration
#

set(PACKAGE_COMPONENTS "")
set(PACKAGE_DEPENDENCIES "")

if(A_ENABLE_Ext)
  list(APPEND PACKAGE_COMPONENTS "Ext")
  list(APPEND PACKAGE_DEPENDENCIES "Y")
endif()

if(A_ENABLE_X)
  list(APPEND PACKAGE_DEPENDENCIES "X")
endif()

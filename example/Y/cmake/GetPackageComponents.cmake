#
# This is DependencyResolver dynamic configuration
#

# Which components shall be built ?
set(PACKAGE_COMPONENTS "*")

# Which dependencies shall be enabled ?
set(PACKAGE_DEPENDENCIES "")
if(Y_ENABLE_BExt)
  list(APPEND PACKAGE_DEPENDENCIES "B.Ext")
endif()
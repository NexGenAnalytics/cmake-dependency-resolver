# cmake-dependency-resolver

_CMake Dependency Resolver_ is a lightweight script that helps connecting packages configured with CMake. It comes in form of a CMake source code that can be included in any project. The only requirement is *CMake 3.19* or newer (with [JSON support](https://cmake.org/cmake/help/latest/command/string.html#json)).

## Glossary

* **_Package_**: independent piece of software with headers, libraries, etc. that can be built and installed.
* **_Component_**: consistent part of _Package_ (subset of headers, libraries, etc.).
* **_Dependency_** of _Package_ or _Component_ on required _Package_ or _Component_.

## Motivation

Primary features of proposed solution and premises on which we're developing it:

1. **Stand-alone mode**: the ability to build packages in standalone mode, where any package can be built on its own (with all required upstream packages).
2. **Support for optional components**: the ability to split packages into parts and minimize builds by disabling unused parts with CMake build options.

**Why CMake is not sufficient ?**

Bare CMake becomes insufficient for dependency resolution when inconsistent diamond dependencies are enabled. With our premises, introducing optional components enable inconsistent diamond dependencies as one package can be required with different component sets. For instance, consider building package `A` with upstream dependencies `X`, `Y` and `B`:

[![inconsitent-diamond.png](doc/inconsitent-diamond.png)](http://www.plantuml.com/plantuml/uml/SoWkIImgAStDuIfAJIv9p4lFILLmKgZcKb10uXkYSesuQhcGb2j4GDKZ10o1Ab2KHA8hYJH4CyGHNOKZn10dGmKRNLsGaKv681P8PmHO3AGY4ivIvt98pKi1UWG0)

Packages `X` and `Y` have inconsistent dependencies on `B` - with components `B1` and `B2` respectively. If naive method traversed over packages/directories in order `A`, `X`, `B`, `Y`, it would only enable `B1` on `B` (required by `X`). If the order was `A`, `Y`, `B`, `X`, it would only enable `B2` on `B` (required by `Y`). Either way the other component would remain disabled causing build failure, because no pacakge/directory can be visited twice - neither by `add_subdirectory()` nor by `find_package()`.

> *Note:* Version ranges provide another, more sophisticated, example of feature enabling inconsitent diamond dependencies: for instance `X` could require `B` with versions 3-5 and `Y` with 1-3. Build would fail if `B` version picked is differnet than 3 (e.g. `X` enables `B` with version 5).

## Alternatives compared

| Feature | CMakeDependencyResolver | TriBITS |
|---|---|---|
| Stand-alone mode | **Yes** | No: packages built within project |
| Usage | Library: package only calls `add_and_resolve_package_dependencies()` function to trigger dependency resolution | Framework: structure required for project, packages and components (sub-packages) |
| Components enabling build options | Flexible / unrestricted | Predefined format (`PACKAGE_ENABLE_SUBPACKAGE`) |
| Dependency enabling build options | Flexible / unrestricted | Predefined format (`PACKAGE_ENABLE_DEPENDENCY`) |
| Static package configuration | Package JSON file | CMake files for package and all components |
| Dynamic package configuration | Package CMake file | not needed due to predefined format of build options |
| Support for optional components | Yes | Yes |
| Support for component level dependencies | Yes | Yes |
| Distribution form | CMake source file | CMake source file |
| Support for `find_package()` dependencies | No | **Yes** |
| Automated target linking | No | **Yes** |
| Automated test linking | No | **Yes** |
| Automated exports and installation | No | **Yes** |

## API

In progress - See [well-documented example](example)
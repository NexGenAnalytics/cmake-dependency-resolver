# cmake-dependency-resolver

Developing a project with packages contianing optional components and having inter-dependencies ? _CMake Dependency Resolver_ is a lightweight _script_ (single CMake file) that resolves the dependencies between packages (and components) configured with CMake.

Primary features of proposed solution and premises on which we're developing it:

1. **Self-contained packages**: the ability to build any selected package with it's required upstream packages.
2. **Peer-to-peer dependency resolution:** dependecy resolution is triggered on the starting package and goes to all upstream packages. No central/top-level coordination needed.
3. **Support for optional components**: the ability to split packages into parts and minimize builds by disabling unused parts with CMake build options.

 The only requirement is *CMake 3.19* or newer (with [JSON support](https://cmake.org/cmake/help/latest/command/string.html#json))
## Glossary

* **_Project_**: piecie of software composed of - or depending on - multiple packages.
* **_Package_**: independent piece of software with headers, libraries, etc. that can be built and installed.
* **_Component_**: logical part of _Package_ (subset of headers, libraries, etc.) that is optional in build and installation.
* **_Dependency_**: package or component requiring other packages and their component:
  - package level: package to package;
  - component level: package to component, component to package

**Why CMake is not sufficient ?**

Consider a scenario with packages `A`, `B`, `C` and `D` withe their respective components: `A1`, `B1`, `C1`, `D1` and `D2`. Bare CMake becomes insufficient for dependency resolution when inconsistent diamond-shaped dependencies are enabled. With our premises, introducing optional components enable inconsistent diamond-shaped dependencies as one package can be required with different component sets. For instance, consider building package `A` with upstream dependencies `B`, `C` and `D`:

[![inconsitent-diamond.png](doc/inconsitent-diamond.png)](http://www.plantuml.com/plantuml/uml/SoWkIImgAStDuIfAJIv9p4lFILLmKgZcKb10uXkYSesuQhcGb2j4GDKZ10o1Ab2KHA8hYJH4CyGHNOKZn10dGmKRNLsGaKv681P8PmHO3AGY4ivIvt98pKi1UWG0)

Packages `B` and `C` have inconsistent dependencies on `D` - with components `D1` and `D2` respectively. If naive method traversed over packages/directories in order `A`, `B`, `D`, `C`, it would only enable `D1` on `D` (required by `B`). If the order was `A`, `C`, `D`, `B`, it would only enable `D2` on `D` (required by `C`). Either way the other component would remain disabled causing build failure, because no pacakge/directory can be visited twice - neither by `add_subdirectory()` nor by `find_package()`.

> *Note:* Version ranges provide another, more sophisticated, example of feature enabling inconsitent diamond-shaped dependencies: for instance `B` could require `D` with versions 3-5 and `C` with 1-3. Build would fail if `D` version picked is differnet than 3 (e.g. `B` enables `D` with version 5).

## Alternatives compared

| Feature | CMakeDependencyResolver | TriBITS |
|---|---|---|
| CMake structure | Each package is self-contained CMake project | Each package requires top-level TriBITS Project |
| Dependency resolution | Local (peer-to-peer) triggered at package level | Global - triggered at top project level |
| Folder and code structure | Arbitrary | must follow framework requirements |
| Dependency specification | Package JSON file + dynamic CMake callback | CMake files for package and all components |
| Support for optional components | Yes | Yes |
| Support for component-package and component-component dependencies | Yes | Yes |
| Automated target and test linking | out of current scope | Yes |
| Automated exports and installation | out of current scope | Yes |

## API

In progress - See [well-documented example](example)
# Python3 for the OpenHarmony Platform

[中文文档](./README_zh.md)

> [!NOTE]
>
> Not just Python, not just source-level migration solutions.
>
> We also distribute pre-compiled binary libraries (system-wide) along with corresponding package managers, enabling developers to directly install libraries not integrated into the official SDK or your OHOS system, thereby simplifying the development process.
>
> See: [OH Packager](https://github.com/SSRVodka/oh-packager)；

This repository provides only a comprehensive migration solution at the source code level. You can easily migrate other required libraries based on this foundation.

We have already ported:

- 70+ system-wide libraries. See: [VERSIONS](./VERSIONS)
- Python3 (currently support 3.12.12 AND 3.11.4)
- some third-party libraries that depend on C/C++ modules to OpenHarmony Edu 5.0.2. 

## Progress

- [x] 70+ system libraries (e.g. openblas, binutils, zstd, curl, ...)
- [x] Python interpreter, and common native libraries: libaacplus, x264, alsa-lib, ffmpeg, bzip2, gettext, libffi, ncurses, OpenBLAS, openssl, readline, sqlite3, xz, zlib;
- [x] Python third-party libraries: numpy, scipy, opencv, onnxruntime;
- [ ] ......
- [ ] If you have third-party libraries to build / ideas and methods to build, please feel free to raise issues / PRs.

## Background

OpenHarmony (OH), the next-generation open source operating system for the era of full scenarios and full connectivity, is gaining influence day by day. Building a thriving application ecosystem is a key cornerstone for OpenHarmony's sustainable development. In this context, effective support for mainstream development languages and their rich ecosystems has become particularly important. Python, with its simplicity, powerful scientific computing and AI library ecosystems, and broad developer base, is undoubtedly an indispensable part of the ecosystem construction.

Currently, running the Python interpreter on OpenHarmony itself is possible through cross-compilation. However,**the core challenge for the Python ecosystem on OpenHarmony is the migration of its large and complex third-party libraries**. The build process for these third-party libraries presents significant obstacles:

1. **The build system is highly heterogeneous:** Python third-party libraries lack a unified build standard and the build toolchain is highly fragmented. Mainstream solutions include `setuptools`/`distutils` (via `setup.py`), new standard build backends based on `pyproject.toml` (e.g. `build`, `flit`, `hatch`), `meson`, `cmake`, etc., and there even exists support only for specific build methods (e.g. ` pybind11`) or projects that only provide source packages.
2. **Weak native cross-compilation support:** The vast majority of Python third-party library build scripts are not designed with cross-compilation scenarios in mind. Hard-coded paths, compilation options, dependency lookup logic, and native build tool invocations in build scripts (e.g., `setup.py`, `meson.build`) are often not directly applicable or require a lot of customization when cross-compiling for non-host target platforms such as OH.
3. **Migration efforts are highly customized and resource intensive:** The above challenges are a direct result of the fact that the process of migrating any Python third-party library to the OpenHarmony platform often requires in-depth analysis, problem identification, and build script adaptation for **each specific library**. Such a “break-by-break” model is highly repetitive and requires a high level of technical threshold for migrators, which seriously hinders the rapid deployment of the Python ecosystem on the OH.

Therefore, there is an urgent need for a systematic solution to address the problem of cross-compiling Python third-party libraries on OpenHarmony.

## Objectives

The goal of this project is to systematically solve the problem of cross-compiling Python and its core third-party libraries on the OpenHarmony platform, and ultimately improve the efficiency and maintainability of the entire migration process. The specific goals are as follows:

1. **Provide reusable cross-compilation practice guides and scripts:** Create and continuously maintain an exhaustive repository that collects, organizes, and provides **specific configuration scenarios for cross-compiling the Python interpreter itself** and **widely-used Python third-party libraries** on OpenHarmony, build scripts (e.g., patches, customized build commands), and detailed step-by-step instructions**. Provide developers with practice templates that they can directly refer to or learn from. 2.
2. **Build base cross-compilation toolchain support:** Develop a set of generic **base tool scripts or configuration modules** that encapsulate the core parameters of OpenHarmony cross-compilation. These tools handle tedious and error-prone low-level details such as OH SDK paths, cross-compiler selection (`clang`), system root (`sysroot`), target architecture flags, required environment variable settings, etc., and provide a consistent base environment for migration of upper-level libraries.
3. **Summary of build patterns and problem pattern libraries:** Based on the accumulated experience of migrating a large number of third-party libraries, we have **systematically categorized the build systems of Python libraries (e.g., `setuptools`/legacy `setup.py`, PEP 517/518 build based on `pyproject.toml`, `meson`, `cmake`, etc.)**, which are used for the migration of Python libraries. cmake`, etc.)**, and for each type of build system, **summarize the typical problems encountered when performing OH cross-compilation and the common solution patterns**.
4. **Abstracting and developing a general-purpose migration toolbase (Long-term Vision):** Based on the accumulated scripts, configurations, and pattern libraries, we finally **designed and implemented a higher-level, relatively general-purpose Python on OpenHarmony cross-compilation assistance toolbase**. This toolkit aims to significantly reduce the technical barrier, duplication of effort, and burden on the developer's mind when migrating new Python libraries to the OH platform, by providing smarter encapsulation of the build process, and automated mechanisms for avoiding or fixing common problems.

## Technical Solution

This project adopts a phased, incremental evolution of the technical route, combined with practical accumulation and abstract refinement.

The solution is to first build some common cross-compilation script tools (e.g., configure OH-related cross-compilation toolchain parameters, necessary and common environment variables, and other tedious details), then summarize the types of common third-party libraries' build tools (meson, pypi-build, `setup.py`, etc.), and summarize the corresponding common problems and special configurations required by these types. and where special configuration is needed. In the future, we plan to abstract a more general Python on OH cross-compile scripting toolkit.

The project has already defined some common cross-compilation scripting tools, and is accumulating a list of common third-party libraries.

## How to build 

Using Ubuntu hosting environment as an example. The OpenHarmony (Edu) SDK needs to be configured. 

- Set the environment variable `OHOS_SDK` (it is recommended to write `.bashrc/.zshrc`) to the root directory of your OpenHarmony (Edu) SDK. Note that it needs to contain the API version number, e.g. `[...] /14`; 

- Install required build tools: All dependencies are listed in the [DEPS](./DEPS) file. You can run `source ./DEPS` in your build environment for one-click installation, or open the file to review specific requirements;

- Download source code before compilation. Since the total size of all libraries and packages exceeds tens of gigabytes, downloading everything on a personal laptop is impractical. Download scripts (all `download-*.sh`) are provided for each component, allowing you to download only what you need. For example: If you only need to build the Python interpreter and its dependencies, simply run `./download-python.sh`.

- Compile using the downloaded libraries:

  - For example, to build the Python interpreter and its dependencies, simply run `./build-python.sh`;

  - To build Python packages, you must first complete the Python interpreter build, then download the corresponding source code before compiling. Relevant script: `./build-pypkg-xxx.sh`. Note:

	- For OpenCV, you must also compile FFmpeg and first run `./build-pypkg-numpy-scipy.sh` to compile and install numpy into crossenv;

    - For SciPy, compiling OpenBLAS for acceleration is recommended: `./build-openblas.sh`;

	- If onnxruntime is required, since it currently only supports up to 1.18.2, numpy version < 2 is needed. You may need to modify the build script to compile a lower numpy version.

- (Deprecated) The `-d` parameter downloads source code for various dependencies and is only needed on the first run. If you wish to handle downloads manually, omit `-d` and run `download-*.sh` first;

- Native library outputs reside in `dist.<arch>.<package_name>`, while Python wheel outputs are in `dist.wheel` (some may actually be located in `xxx(package_name)/dist` directories);


## How to Add Required Libraries Yourself?

- If you wish to add a third-party system library to the build process, simply add one line of code, following the format used in `build-misc.sh`.

- If you want to build a third-party Python library, you need to download the relevant repository and manually build the third-party library by following the format used in `build-pypkg-xxx.sh`.

- For binary distribution of system dependency libraries, refer to [OH Packager](https://github.com/SSRVodka/oh-packager).

- This repository provides sample builds for some third-party libraries (`numpy`, `scipy`). See the Releases section.

- Feel free to submit a PR with your additions.


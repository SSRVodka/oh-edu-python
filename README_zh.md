
# 适用于 OpenHarmony EDU 平台的 Python3

本仓库将 Python3 (目前 3.11.4) 以及部分依赖于 C/C++ 模块的第三方库移植到 OpenHarmony Edu 5.0.2。



## 背景

OpenHarmony (OH) 作为面向全场景、全连接时代的下一代开源操作系统，其影响力与日俱增。构建繁荣的应用生态是 OpenHarmony 持续发展的关键基石。在此背景下，**对主流开发语言及其丰富生态的有效支持**变得尤为重要。Python，凭借其简洁性、强大的科学计算与人工智能库生态以及广泛的开发者基础，无疑是生态建设中不可或缺的一环。

当前，在 OpenHarmony 上运行 Python 解释器本身已可通过交叉编译实现。然而，**Python 生态在 OpenHarmony 上的落地面临的核心挑战在于其庞大且复杂的第三方库的迁移适配**。这些第三方库的构建过程存在显著障碍：

1. **构建系统异构性严重：** Python 第三方库缺乏统一的构建标准，构建工具链高度碎片化。主流方案包括 `setuptools`/`distutils` (通过 `setup.py`)、基于 `pyproject.toml` 的新标准构建后端（如 `build`, `flit`, `hatch`）、`meson`、`cmake` 等，甚至存在仅支持特定构建方式（如 `pybind11`）或仅提供源码包的项目。
2. **原生交叉编译支持薄弱：** 绝大多数 Python 第三方库的构建脚本在设计时并未充分考虑交叉编译场景。构建脚本（如 `setup.py`, `meson.build`）中硬编码的路径、编译选项、依赖查找逻辑以及原生构建工具的调用方式，在面向 OH 这类非宿主目标平台进行交叉编译时，往往无法直接适用或需要大量定制化修改。
3. **迁移工作高度定制化与资源密集：** 上述挑战直接导致将任意 Python 第三方库迁移至 OpenHarmony 平台的过程，通常需要针对**每个特定库**进行深入分析、问题定位和构建脚本的适配调整。这种“逐个击破”的模式工程量大、重复性高，且对迁移人员的技术门槛要求较高，严重阻碍了 Python 生态在 OH 上的快速落地。

因此，亟需系统化的方案来应对 Python 第三方库在 OpenHarmony 上的交叉编译难题。

## 目标

本项目旨在系统性地解决 Python 及其核心第三方库在 OpenHarmony 平台上的交叉编译问题，并最终提升整个迁移过程的效率和可维护性。具体目标如下：

1. **提供可复用的交叉编译实践指南与脚本：** 建立并持续维护一个详尽的仓库，收集、整理和提供 **Python 解释器本身**以及**广泛使用的 Python 第三方库**在 OpenHarmony 上进行交叉编译的**具体配置方案、构建脚本（如补丁、定制化构建命令）和详细步骤说明**。为开发者提供可直接参考或借鉴的实践模板。
2. **构建基础交叉编译工具链支撑：** 开发一组通用的、封装了 OpenHarmony 交叉编译核心参数的**基础工具脚本或配置模块**。这些工具负责处理如 OH SDK 路径、交叉编译器选择 (`clang`)、系统根目录 (`sysroot`)、目标架构标志、必需的环境变量设置等繁琐且易错的底层细节，为上层库的迁移提供一致的基础环境。
3. **总结构建模式与问题模式库：** 在积累大量第三方库迁移经验的基础上，对 Python 库的构建系统进行**系统化分类（如 `setuptools`/传统 `setup.py`、基于 `pyproject.toml` 的 PEP 517/518 构建、`meson`、`cmake` 等）**，并针对每类构建系统，**归纳总结其在进行 OH 交叉编译时遇到的典型问题和通用的解决方案模式**。
4. **抽象并开发通用迁移工具库 (Long-term Vision)：** 基于前期积累的脚本、配置和模式库，最终**设计并实现一个更高级别的、相对通用的 Python on OpenHarmony 交叉编译辅助工具库**。该工具库旨在通过提供更智能的构建流程封装、常见问题的自动规避或修复机制，显著降低新 Python 库迁移到 OH 平台的技术门槛、重复工作量和开发者心智负担。

## 技术方案

本项目采用分阶段、渐进式演进的技术路线，结合实践积累与抽象提炼。

解决方案是先构建一些通用的交叉编译脚本工具（例如配置 OH  相关的交叉编译工具链参数、必须且通用的环境变量等等繁琐细节），然后通过人力总结各个常见第三方库的构建工具类型（区分  meson、pypi-build、`setup.py` 等），针对这些类型总结对应的常见问题以及需要特殊配置的地方。后期计划抽象出一个较为通用的 Python  on OH 的交叉编译脚本工具库。

本项目的目前已经定义了一些通用的交叉编译脚本工具，正在积累常见第三方库的构建方式。已经交叉编译的：

- Python 或第三方库需要的 Native 依赖：libaacplus、x264、alsa-lib、ffmpeg、bzip2、gettext、libffi、ncurses、OpenBLAS、openssl、readline、sqlite3、xz、zlib；
- Python 解释器；
- Python 第三方库：numpy、scipy、opencv、onnxruntime；

如果您有需要构建的第三方库，欢迎提 issue，共同建设。

## 如何构建

您可以自行尝试目前已经完成的脚本。

以 Ubuntu 宿主机环境为例。需要配置 OpenHarmony (EDU) SDK。

- 设置环境变量 `OHOS_SDK`（建议写入 `.bashrc/.zshrc`）为你的 OpenHarmony SDK 的根目录。请注意，它需要包含 API 版本号，例如 `[...]/14`；

- 安装必要构建工具：

  ```shell
  sudo apt install \
  	git \
  	wget \
  	unzip \
  	build-essential \
  	autoconf \
  	autopoint \
  	libtool \
  	texinfo \
  	po4a
  ```

- 执行 `./ohos-build.sh -d`（`-d` 参数表示下载各种依赖库的源码）开始编译，产物位于同父目录下的 `dist/` 目录中。

如果你想要构建第三方 Python 库，则需要模仿 `pypkgs-download.sh` 下载相关仓库，模仿 `scipy-build.sh` 手动构建第三方库。

本仓库提供了部分构建的第三方库样例（`numpy`、`scipy`），参见 Release。



## 已知问题

- `libreadline.so` 通过 Clang 工具链的编译，但是还是出现无法识别符号的问题。怀疑是 OpenHarmony 编译工具链或 musl libc 系统库自身问题：

    <img src="imgs/issue2.png" />
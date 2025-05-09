
# 适用于 OpenHarmony Edu 平台的 Python3

本仓库将 Python3 (目前 3.11.4) 以及部分依赖于 C/C++ 模块的第三方库移植到 OpenHarmony Edu 5.0.2。

<img src="imgs/cover.png" />



## 如何构建

以 Ubuntu 宿主机环境为例。需要配置 OpenHarmony (Edu) SDK。

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
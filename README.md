# Python3 for the OpenHarmony Platform

[中文文档](./README_zh.md)

This repository ports Python3 (currently 3.11.4) to OpenHarmony Edu 5.0.2. 

<img src="imgs/cover.png" /> 



## How to build 

Using Ubuntu hosting environment as an example. The OpenHarmony (Edu) SDK needs to be configured. 

- Set the environment variable `OHOS_SDK` (it is recommended to write `.bashrc/.zshrc`) to the root directory of your OpenHarmony (Edu) SDK. Note that it needs to contain the API version number, e.g. `[...] /14`; 

- Install the necessary build tools: 

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

- Execute `. /ohos-build.sh -d` (the `-d` parameter means to download the source code of the various dependency libraries) to start the build, the product is located in the `dist/` directory in the same parent directory.



## Known Issues

- [Fixed] Python module under `lib-dynload` fails to load symbols in `libpython3.so`; 

- ` libreadline.so` is compiled with the Clang toolchain, but still has the problem of not recognizing symbols. Suspect OpenHarmony build toolchain or musl libc system library itself: 

    <img src="imgs/issue2.png" />

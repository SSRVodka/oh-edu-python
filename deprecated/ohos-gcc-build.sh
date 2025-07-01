#!/bin/bash
set -Eeuo pipefail

CUR_DIR=$(dirname $(readlink -f $0))
OLD_PATH=$PATH

trap "export PATH=${OLD_PATH}; unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LDSHARED CROSS_COMPILE" ERR SIGINT SIGTERM

if [ -z "${OHOS_SDK}" ]; then
	echo "[TIPS] please set OHOS_SDK env first"
	exit 0
fi
#OHOS_GCC_TOOLCHAIN_ROOT=/home/xhw/Desktop/OH/oh-edu-python/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu/bin
if [ -z "${OHOS_GCC_TOOLCHAIN_ROOT}" ]; then
	echo "[TIPS] please set OHOS_GCC_TOOLCHAIN_ROOT env first"
	exit 0
fi

CMAKE_BIN=${OHOS_SDK}/native/build-tools/cmake/bin/cmake
CMAKE_TOOLCHAIN_CONFIG=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake

OHOS_CPU=aarch64
OHOS_ARCH=arm64-v8a
# OHOS_CPU=arm
# OHOS_ARCH=armeabi-v7a
#OHOS_CPU=x86_64
#OHOS_ARCH=x86_64

TARGET_ROOT=${CUR_DIR}/dist-gcc
TEST_DIR=${CUR_DIR}/test-only

HOST_LIBC=${OHOS_SDK}/native/sysroot/usr/lib/${OHOS_CPU}-linux-ohos/libc.so
BUILD_PLATFORM_PYTHON=${OHOS_SDK}/native/llvm/python3/bin/python3

OHOS_GCC_TOOLCHAIN_PREFIX=${OHOS_CPU}-linux-gnu-

export CROSS_COMPILE="${OHOS_GCC_TOOLCHAIN_ROOT}/${OHOS_GCC_TOOLCHAIN_PREFIX}"

export CFLAGS="-fPIC -D__MUSL__=1 -I${TARGET_ROOT}/include -I${TARGET_ROOT}/include/lzma -I${TARGET_ROOT}/include/ncursesw -I${TARGET_ROOT}/include/readline -I${TARGET_ROOT}/ssl/include"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="${CXXFLAGS}"
export LDFLAGS="-L${TARGET_ROOT}/lib -L${TARGET_ROOT}/ssl/lib64"
export LDSHARED="${CROSS_COMPILE}gcc ${LDFLAGS} -shared"

export PATH=${OHOS_SDK}/native/llvm/bin:${OHOS_SDK}/native/toolchains:$PATH

ohos_configure() {
    CC="${CROSS_COMPILE}gcc" \
    CXX="${CROSS_COMPILE}g++" \
    AS="${CROSS_COMPILE}as" \
    LD="${CROSS_COMPILE}ld" \
    LDXX="${LD}" \
    STRIP="${CROSS_COMPILE}strip" \
    RANLIB="${CROSS_COMPILE}ranlib" \
    OBJDUMP="${CROSS_COMPILE}objdump" \
    OBJCOPY="${CROSS_COMPILE}objcopy" \
    READELF="${CROSS_COMPILE}readelf" \
    NM="${CROSS_COMPILE}nm" \
    AR="${CROSS_COMPILE}ar" \
    PROFDATA="${CROSS_COMPILE}profdata" \
    "$@"
}

# add -shared to C/CXXFLAGS
cd zlib
ohos_configure ./configure --prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd openssl
./Configure linux-aarch64 shared zlib \
       --cross-compile-prefix=${CROSS_COMPILE} \
       --prefix=${TARGET_ROOT}/ssl \
       --openssldir=${TARGET_ROOT}/ssl
make -j
make install
cd ..

cd libffi
./autogen.sh
ohos_configure ./configure \
       --target=${OHOS_CPU}-linux-musl \
       --host=${OHOS_CPU}-linux-musl \
       --build=x86_64-pc-linux-gnu \
       --enable-shared \
       --prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd sqlite
ohos_configure ./configure \
       --host=${OHOS_CPU}-linux-musl \
       --build=x86_64-pc-linux-gnu \
       --enable-shared \
       --prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd bzip2
# git apply ../bzip2.patch
make CC="${CROSS_COMPILE}gcc" AR="${CROSS_COMPILE}ar" RANLIB="${CROSS_COMPILE}ranlib" LDFLAGS="${LDFLAGS}" CFLAGS="${CFLAGS}" PREFIX="${TARGET_ROOT}" LDSHARED="${LDSHARED}" -f Makefile-libbz2_so
make CC="${CROSS_COMPILE}gcc" AR="${CROSS_COMPILE}ar" RANLIB="${CROSS_COMPILE}ranlib" LDFLAGS="${LDFLAGS}" CFLAGS="${CFLAGS}" PREFIX="${TARGET_ROOT}"
make install PREFIX="${TARGET_ROOT}"
# install bzip dynamic library
cp libbz2.so.* ${TARGET_ROOT}/lib
cp bzip2-shared ${TARGET_ROOT}/bin
cd ..

cd xz
./autogen.sh
ohos_configure ./configure \
       --target=${OHOS_CPU}-linux-musl \
       --host=${OHOS_CPU}-linux-musl \
       --build=x86_64-pc-linux-gnu \
       --enable-shared \
       --prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd ncurses
ohos_configure ./configure \
       --target=${OHOS_CPU}-linux-musl \
       --host=${OHOS_CPU}-linux-musl \
       --build=x86_64-pc-linux-gnu \
       --without-progs \
       --with-shared \
       --prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd readline
ohos_configure ./configure \
       --target=${OHOS_CPU}-linux-musl \
       --host=${OHOS_CPU}-linux-musl \
       --build=x86_64-pc-linux-gnu \
       --enable-shared \
       --prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd gettext
ohos_configure ./configure \
       --target=${OHOS_CPU}-linux-musl \
       --host=${OHOS_CPU}-linux-musl \
       --build=x86_64-pc-linux-gnu \
       --enable-shared \
       --prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd Python
# patch configure: ohos triplet not supported
sed -i '/MULTIARCH=\$($CC --print-multiarch 2>\/dev\/null)/a PLATFORM_TRIPLET=$MULTIARCH' configure
ohos_configure ./configure --target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--enable-shared \
	--disable-ipv6 \
	--with-build-python=${BUILD_PLATFORM_PYTHON} \
	--with-ensurepip=install \
	--with-readline=readline \
	--with-openssl=${TARGET_ROOT}/ssl \
	--enable-loadable-sqlite-extensions \
	--prefix=${TARGET_ROOT} \
	ac_cv_file__dev_ptmx=yes \
	ac_cv_file__dev_ptc=no
make -j
make install


# restore old $PATH value
export PATH=$OLD_PATH
unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LDSHARED CROSS_COMPILE

#!/bin/bash
set -Eeuo pipefail

cd $(dirname $(readlink -f $0))

DOWNLOAD=0
while getopts "d" arg
do
    case $arg in
    d)
        DOWNLOAD=1
        ;;
    ?)
        echo "Unknown argument: $arg. Ignored."
        ;;
    esac
done
if [ "$DOWNLOAD" -eq 1 ]; then
    ./download.sh
fi

OLD_PATH=$PATH

trap "export PATH=${OLD_PATH}; unset CC CXX AS LD LDXX LLD STRIP RANLIB OBJDUMP OBJCOPY READELF NM AR PROFDATA CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LDSHARED" ERR SIGINT SIGTERM

if [ -z "${OHOS_SDK}" ]; then
	echo "[TIPS] please set OHOS_SDK env first"
	exit 0
fi

CMAKE_BIN=${OHOS_SDK}/native/build-tools/cmake/bin/cmake
CMAKE_TOOLCHAIN_CONFIG=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake

# OHOS_CPU=aarch64
# OHOS_ARCH=arm64-v8a
# OHOS_CPU=arm
# OHOS_ARCH=armeabi-v7a
OHOS_CPU=x86_64
OHOS_ARCH=x86_64

TARGET_ROOT=/home/xhw/Desktop/OH/oh-edu-python/dist
TEST_DIR=/home/xhw/Desktop/OH/oh-edu-python/test-only

HOST_LIBC=${OHOS_SDK}/native/sysroot/usr/lib/${OHOS_CPU}-linux-ohos/libc.so
BUILD_PLATFORM_PYTHON=${OHOS_SDK}/native/llvm/python3/bin/python3

export CC="${OHOS_SDK}/native/llvm/bin/clang --target=${OHOS_CPU}-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=${OHOS_CPU}-linux-ohos"
export AS=${OHOS_SDK}/native/llvm/bin/llvm-as
export LD=${OHOS_SDK}/native/llvm/bin/ld.lld
export LDXX=${LD}
export LLD=${LD}
export STRIP=${OHOS_SDK}/native/llvm/bin/llvm-strip
export RANLIB=${OHOS_SDK}/native/llvm/bin/llvm-ranlib
export OBJDUMP=${OHOS_SDK}/native/llvm/bin/llvm-objdump
export OBJCOPY=${OHOS_SDK}/native/llvm/bin/llvm-objcopy
export READELF=${OHOS_SDK}/native/llvm/bin/llvm-readelf
export NM=${OHOS_SDK}/native/llvm/bin/llvm-nm
export AR=${OHOS_SDK}/native/llvm/bin/llvm-ar
export PROFDATA=${OHOS_SDK}/native/llvm/bin/llvm-profdata
export CFLAGS="-fPIC -D__MUSL__=1 -I${TARGET_ROOT}/include -I${TARGET_ROOT}/include/lzma -I${TARGET_ROOT}/include/ncursesw -I${TARGET_ROOT}/include/readline -I${TARGET_ROOT}/ssl/include"
export CXXFLAGS=${CFLAGS}
export CPPFLAGS=${CXXFLAGS}
export LDFLAGS="-fuse-ld=lld -L${TARGET_ROOT}/lib -L${TARGET_ROOT}/ssl/lib64 -lcrypt"
export LDSHARED="${CC} ${LDFLAGS} -shared"

export PATH=${OHOS_SDK}/native/llvm/bin:${OHOS_SDK}/native/toolchains:$PATH

# add -shared to C/CXXFLAGS
cd zlib
./configure --prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd openssl
./Configure shared zlib \
	--prefix=${TARGET_ROOT}/ssl \
	--openssldir=${TARGET_ROOT}/ssl
make -j
make install
cd ..

cd libffi
./autogen.sh
./configure --target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--enable-shared \
	--prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd sqlite
./configure --host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--enable-shared \
	--prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd bzip2
# remove cross compile test
# sed -i.bak -e '/^all:/ s/ test//' -e '/^dist:/ s/ check//' Makefile
sed -i -e '/^all:/ s/ test//' -e '/^dist:/ s/ check//' Makefile
make CC="${CC}" AR="${AR}" RANLIB="${RANLIB}" LDFLAGS="${LDFLAGS}" CFLAGS="${CFLAGS} -shared" PREFIX="${TARGET_ROOT}" -f Makefile-libbz2_so
make CC="${CC}" AR="${AR}" RANLIB="${RANLIB}" LDFLAGS="${LDFLAGS}" CFLAGS="${CFLAGS}" PREFIX="${TARGET_ROOT}"
make install PREFIX="${TARGET_ROOT}"
# install bzip dynamic library
cp libbz2.so.* ${TARGET_ROOT}/lib
cp bzip2-shared ${TARGET_ROOT}/bin
cd ..

cd xz
./autogen.sh
./configure --target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--enable-shared \
	--prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd ncurses
./configure --target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--without-progs \
	--with-shared \
	--prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd readline
./configure --target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--enable-shared \
	--prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd gettext
./configure --target=${OHOS_CPU}-linux-musl \
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
./configure --target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--disable-ipv6 \
	--enable-shared \
	--with-libc=${HOST_LIBC} \
	--with-build-python=${BUILD_PLATFORM_PYTHON} \
	--with-ensurepip=install \
	--with-readline=readline \
	--with-openssl=${TARGET_ROOT}/ssl \
	--enable-loadable-sqlite-extensions \
	--prefix=${TARGET_ROOT} \
	ac_cv_file__dev_ptmx=yes \
	ac_cv_file__dev_ptc=no \
	CC="${CC}" CXX="${CXX}" RANLIB="${RANLIB}" STRIP="${STRIP}" AR="${AR}" CFLAGS="${CFLAGS}" CPPFLAGS="${CPPFLAGS}" LD="${LD}" LDXX="${LDXX}" NM="${NM}" OBJDUMP="${OBJDUMP}" OBJCOPY="${OBJCOPY}" READELF="${READELF}" PROFDATA="${PROFDATA}" LDFLAGS="${LDFLAGS}" 
make -j
make install
cd ..

# restore old $PATH value
export PATH=$OLD_PATH
unset CC CXX AS LD LDXX LLD STRIP RANLIB OBJDUMP OBJCOPY READELF NM AR PROFDATA CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LDSHARED

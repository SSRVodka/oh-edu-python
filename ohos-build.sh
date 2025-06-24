#!/bin/bash
set -Eeuo pipefail

CUR_DIR=$(dirname $(readlink -f $0))
cd $CUR_DIR

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
OLD_LD_LIBPATH=${LD_LIBRARY_PATH:=""}

trap "export PATH=${OLD_PATH}; export LD_LIBRARY_PATH=${OLD_LD_LIBPATH}; unset CC CXX AS LD LDXX LLD STRIP RANLIB OBJDUMP OBJCOPY READELF NM AR PROFDATA CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LDSHARED" ERR SIGINT SIGTERM

if [ -z "${OHOS_SDK}" ]; then
	echo "[TIPS] please set OHOS_SDK env first"
	exit 0
fi

CMAKE_BIN=${OHOS_SDK}/native/build-tools/cmake/bin/cmake
CMAKE_TOOLCHAIN_CONFIG=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake

#OHOS_CPU=aarch64
#OHOS_ARCH=arm64-v8a
# OHOS_CPU=arm
# OHOS_ARCH=armeabi-v7a
OHOS_CPU=x86_64
OHOS_ARCH=x86_64


TARGET_ROOT=${CUR_DIR}/dist.${OHOS_CPU}
TEST_DIR=${CUR_DIR}/test-only

# Note: Fortran compiler should be changed with ARCH
# Use gnu here instead of ohos: code gen only
FC=${OHOS_CPU}-linux-gnu-gfortran-11
mkdir -p ${TARGET_ROOT}/lib
cp gfortran.libs.${OHOS_CPU}/* ${TARGET_ROOT}/lib


# Build build-python first!
# It must be the same with build-build-python.sh
BUILD_PYTHON_DIST=${CUR_DIR}/build-python.dist
BUILD_PYTHON_DIST_PYTHON=${BUILD_PYTHON_DIST}/bin/python3
./build-build-python.sh ${BUILD_PYTHON_DIST}


HOST_LIBC=${OHOS_SDK}/native/sysroot/usr/lib/${OHOS_CPU}-linux-ohos/libc.so

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
export CFLAGS="-fPIC -D__MUSL__=1 -D__OPENHARMONY__=1 -I${TARGET_ROOT}/include -I${TARGET_ROOT}/include/lzma -I${TARGET_ROOT}/include/ncursesw -I${TARGET_ROOT}/include/readline -I${TARGET_ROOT}/ssl/include"
export CXXFLAGS=${CFLAGS}
export CPPFLAGS=${CXXFLAGS}
export LDFLAGS="-fuse-ld=lld -L${TARGET_ROOT}/lib -L${TARGET_ROOT}/ssl/lib64 -L${CUR_DIR}/gfortran.libs.${OHOS_CPU}"
export LDSHARED="${CC} ${LDFLAGS} -shared"

export PATH=${OHOS_SDK}/native/llvm/bin:${OHOS_SDK}/native/toolchains:$PATH


# add -shared to C/CXXFLAGS
cd zlib
./configure --prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd openssl
./Configure linux-${OHOS_CPU} shared zlib \
	--prefix=${TARGET_ROOT}/ssl \
	--openssldir=${TARGET_ROOT}/ssl
make -j
make install
cd ..

. ffmpeg-build.sh

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
export LD_LIBRARY_PATH=${BUILD_PYTHON_DIST}/lib:$LD_LIBRARY_PATH
# patch configure: ohos triplet not supported
sed -i '/MULTIARCH=\$($CC --print-multiarch 2>\/dev\/null)/a PLATFORM_TRIPLET=$MULTIARCH' configure
./configure --target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--disable-ipv6 \
	--enable-shared \
	--with-libc=${HOST_LIBC} \
	--with-build-python=${BUILD_PYTHON_DIST_PYTHON} \
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
export LD_LIBRARY_PATH=$OLD_LD_LIBPATH
cd ..

# Patch the needed info in *.so
LOST_LIBRARY=libpython3.11.so
DIST_LIB_DYLOAD_PATH=${TARGET_ROOT}/lib/python3.11/lib-dynload
find "${DIST_LIB_DYLOAD_PATH}" -type f -name "*.so" -print0 | while IFS= read -r -d '' sofile; do
    echo "patch dynamic-linked file: $sofile"
    if ! patchelf --add-needed "${LOST_LIBRARY}" "$sofile"; then
        echo "ERROR: failed to process file $sofile" >&2
    fi
done

# Add TARGET=ARMV8 if $OHOS_CPU==aarch64
cd OpenBLAS
make BINARY=64 CC="$CC" FC="$FC" CROSS=1 HOSTCC=gcc
make install PREFIX=${TARGET_ROOT}
#${CMAKE_BIN} \
#	-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_CONFIG} \
#	-DCMAKE_C_FLAGS="${CFLAGS}" \
#	-DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
#	-DLINK_FLAGS="${LDFLAGS}" \
#	-DBUILD_TESTING=OFF \
#	-B cmake_build
#${CMAKE_BIN} --build cmake_build --config Release
cd ..

# restore old $PATH value
export PATH=$OLD_PATH
unset CC CXX AS LD LDXX LLD STRIP RANLIB OBJDUMP OBJCOPY READELF NM AR PROFDATA CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LDSHARED

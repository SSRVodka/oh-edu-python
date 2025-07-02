#!/bin/bash
set -Eeuo pipefail

CUR_DIR=$(dirname $(readlink -f $0))
cd $CUR_DIR

info () { printf "%b%s%b" "\E[1;34m❯ \E[1;36m" "${1:-}" "\E[0m\n"; }
error () { printf "%b%s%b" "\E[1;31m❯ " "ERROR: ${1:-}" "\E[0m\n" >&2; }
warn () { printf "%b%s%b" "\E[1;31m❯ " "Warning: ${1:-}" "\E[0m\n" >&2; }

DOWNLOAD=0
while getopts "d" arg
do
    case $arg in
    d)
        DOWNLOAD=1
        ;;
    ?)
        warn "Unknown argument: $arg. Ignored."
        ;;
    esac
done

OLD_PATH=$PATH
OLD_LD_LIBPATH=${LD_LIBRARY_PATH:=""}

trap "export PATH=${OLD_PATH}; export LD_LIBRARY_PATH=${OLD_LD_LIBPATH}; unset CC CXX AS LD LDXX LLD STRIP RANLIB OBJDUMP OBJCOPY READELF NM AR PROFDATA CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LDSHARED PKG_CONFIG_PATH PKG_CONFIG_LIBDIR PKG_CONFIG_SYSTEM_IGNORE_PATH" ERR SIGINT SIGTERM

if [ -z "${OHOS_SDK}" ]; then
	warn "please set OHOS_SDK env first"
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

ARCH=${OHOS_ARCH}

TARGET_ROOT=${CUR_DIR}/dist.${OHOS_CPU}
TEST_DIR=${CUR_DIR}/test-only

# Note: Fortran compiler should be changed with ARCH
# Use gnu here instead of ohos: code gen only
FC=${OHOS_CPU}-linux-gnu-gfortran-11
mkdir -p ${TARGET_ROOT}/lib
cp gfortran.libs.${OHOS_CPU}/* ${TARGET_ROOT}/lib


HOST_SYSROOT=${OHOS_SDK}/native/sysroot
HOST_LIBC=${HOST_SYSROOT}/usr/lib/${OHOS_CPU}-linux-ohos/libc.so

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

export PKG_CONFIG_SYSTEM_IGNORE_PATH=/usr/local/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig
export PKG_CONFIG_LIBDIR=${HOST_SYSROOT}/usr/lib/${OHOS_ARCH}-linux-ohos
# export PKG_CONFIG_SYSROOT_DIR=${HOST_SYSROOT}


################################# Python Relative Local Envs #################################

# NOTE: you also need to change download-python.sh if you change this
PY_VERSION=3.11
PY_VERSION_CODE=311

BUILD_PYTHON_DIST=${CUR_DIR}/build-python.dist
BUILD_PYTHON_DIST_PYTHON=${BUILD_PYTHON_DIST}/bin/python3

BUILD_PYTHON_BIN="${BUILD_PYTHON_DIST}/bin"
BUILD_PYTHON=$BUILD_PYTHON_BIN/python3
BUILD_PIP=$BUILD_PYTHON_BIN/pip3

HOST_PYTHON_DIST=${TARGET_ROOT}
HOST_PYTHON_BIN="${HOST_PYTHON_DIST}/bin"
HOST_PYTHON=$HOST_PYTHON_BIN/python3
HOST_PIP=$HOST_PYTHON_BIN/pip3
HOST_MESON=$HOST_PYTHON_BIN/meson

# modify ARCH in meson config
sed -i "s/x86_64/${OHOS_ARCH}/g" meson-scripts/ohos-build.meson
sed -i "s/aarch64/${OHOS_ARCH}/g" meson-scripts/ohos-build.meson
sed -i "s/x86_64/${OHOS_ARCH}/g" meson-scripts/scipy-build.meson
sed -i "s/aarch64/${OHOS_ARCH}/g" meson-scripts/scipy-build.meson
sed -i "s/x86_64/${OHOS_ARCH}/g" meson-scripts/scipy-build.numpy2.meson
sed -i "s/aarch64/${OHOS_ARCH}/g" meson-scripts/scipy-build.numpy2.meson

escaped_dir=$(printf '%s\n' "$CUR_DIR" | sed -e 's/[&/\]/\\&/g')
sed -i "s|proj_root[[:space:]]*=[[:space:]]*'[^']*'|proj_root='$escaped_dir'|g" meson-scripts/scipy-build.meson
sed -i "s|proj_root[[:space:]]*=[[:space:]]*'[^']*'|proj_root='$escaped_dir'|g" meson-scripts/scipy-build.numpy2.meson

PY_CROSS_ROOT=${CUR_DIR}/crossenv_${OHOS_ARCH}
HOST_SITE_PKGS=${PY_CROSS_ROOT}/cross/lib/python${PY_VERSION}/site-packages

PYPKG_NATIVE_OUTPUT_DIR=${CUR_DIR}/dist-pypkgs.native.${OHOS_ARCH}
PYPKG_OUTPUT_WHEEL_DIR=${CUR_DIR}/dist.wheels


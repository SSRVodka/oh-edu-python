#!/bin/bash

# https://llvm.org/docs/HowToCrossCompileLLVM.html
# https://discourse.llvm.org/t/trying-to-create-a-pure-llvm-toolchain-on-musl-based-distribution/51545
# https://discourse.llvm.org/t/cross-compile-any-llvm-component-using-clang-only-no-gcc-requirement/80282?page=2
# https://github.com/mstorsjo/llvm-mingw/blob/master/build-compiler-rt.sh
# https://stackoverflow.com/questions/73776689/cross-compiling-with-clang-crtbegins-o-no-such-file-or-directory

set -Eeuo pipefail

# setup flags
. setup.sh

# remove --target
CC="${OHOS_SDK}/native/llvm/bin/clang"
CXX="${OHOS_SDK}/native/llvm/bin/clang++"
CFLAGS="-D__OPENHARMONY__ -D__MUSL__"
CXXFLAGS=$CFLAGS
CPPFLAGS="-D__OPENHARMONY__ -D__MUSL__"
LDFLAGS=""
SYSROOT="$HOST_SYSROOT"
TARGET=${OHOS_CPU}-linux-ohos

EXT_TOOLCHAIN_ROOT=${OHOS_SDK}/native/llvm

#COMMON_LINKER_FLAGS="-fuse-ld=lld ${HOST_SYSROOT}/usr/lib/${TARGET}/Scrt1.o ${HOST_SYSROOT}/usr/lib/${TARGET}/crti.o ${HOST_SYSROOT}/usr/lib/${TARGET}/crtn.o -lc"
COMMON_LINKER_FLAGS="--target=${TARGET} -fuse-ld=lld -Wl,--sysroot=${HOST_SYSROOT} -L${HOST_SYSROOT}/usr/lib/${TARGET}"

cat - <<EOF > $TARGET-clang.cmake
set(CMAKE_SYSTEM_NAME OHOS)
set(CMAKE_SYSROOT "$SYSROOT")
set(CMAKE_C_COMPILER_TARGET $TARGET)
set(CMAKE_CXX_COMPILER_TARGET $TARGET)
set(CMAKE_ASM_COMPILER_TARGET $TARGET)
set(CMAKE_C_FLAGS_INIT "$CFLAGS")
set(CMAKE_CXX_FLAGS_INIT "$CFLAGS")
set(CMAKE_EXE_LINKER_FLAGS "$COMMON_LINKER_FLAGS")
set(CMAKE_SHARED_LINKER_FLAGS "$COMMON_LINKER_FLAGS")
set(CMAKE_LINKER_TYPE LLD)
set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF

MUSL_DIST="${TARGET_ROOT}.musl/usr"
LLVM_DIST=${TARGET_ROOT}.llvm
LLVM_RES_DIR=${LLVM_DIST}/lib/clang/21

COMP_FLAGS="-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_INSTALL_PREFIX=${LLVM_DIST} \
-DCMAKE_VERBOSE_MAKEFILE=ON \
-DHAVE_THREAD_SAFETY_ATTRIBUTES=0 \
-DHAVE_POSIX_REGEX=0 \
-DHAVE_STEADY_CLOCK=0"

CONF_FLAGS="-DLIBCXX_HAS_MUSL_LIBC=ON \
-DCOMPILER_RT_BUILD_GWP_ASAN=OFF \
-DLIBOMP_OMPD_GDB_SUPPORT=OFF \
-DLLVM_NATIVE_TOOL_DIR=/usr/bin \
-DCROSS_TOOLCHAIN_FLAGS_NATIVE=\"-DLLVM_NATIVE_TOOL_DIR=/usr/bin;-DCMAKE_SYSROOT=/usr;-DLLVM_DEFAULT_TARGET_TRIPLE=${BUILD_PLATFORM_TRIPLET}\" \
-DLLVM_HOST_TRIPLE=${TARGET} \
-DCOMPILER_RT_DEFAULT_TARGET_TRIPLE=${TARGET} \
-DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON \
"
#-DLIBOMP_FORTRAN_MODULES_COMPILER=/usr/bin/flang-new
# FIXME: ohos triple is not normalized, the inconsistent triple will cause runtimes build error
# export NO_NORMALIZE_TRIPLE=1

# patch for OHOS
sed -i '/__OPENHARMONY__/! s/^\(#if defined(__ANDROID__)\)\(.*\)$/\1 || defined(__OPENHARMONY__)\2/' \
	llvm/openmp/runtime/src/kmp.h
sed -i '\|__OPENHARMONY__|! s|^\(#if defined(__x86_64__) \&\& defined(__ELF__) \&\& defined(__linux__)\)\(.*\)$|\1 \&\& !defined(__OPENHARMONY__)\2|g' \
	llvm/llvm/tools/llvm-rtdyld/llvm-rtdyld.cpp

pushd llvm
LLVM_LIBSUFFIX="${OHOS_LIBDIR#*/}"
LLVM_EXTFLAG=""
if [ ! $LLVM_LIBSUFFIX == "$OHOS_LIBDIR" ]]; then
	LLVM_EXTFLAG="-DLLVM_LIBDIR_SUFFIX=/${LLVM_LIBSUFFIX}"
fi
$CMAKE_BIN \
	${COMP_FLAGS} \
	-DCMAKE_INSTALL_LIBDIR=${OHOS_LIBDIR} \
	-DCMAKE_INSTALL_PACKAGEDIR=${OHOS_LIBDIR}/cmake \
	${LLVM_EXTFLAG} \
	-DLLVM_ENABLE_PROJECTS="lld;clang" \
	-DCMAKE_TOOLCHAIN_FILE=$(pwd)/../$TARGET-clang.cmake \
	-DLLVM_LINK_LLVM_DYLIB=ON \
	-DLLVM_HOST_TRIPLE=$TARGET \
	-S llvm \
	-B ohos-build
$CMAKE_BIN --build ohos-build -- -j20
$CMAKE_BIN --install ohos-build

# native build
$CMAKE_BIN \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_VERBOSE_MAKEFILE=ON \
	-DLLVM_ENABLE_PROJECTS="lld;clang" \
	-DLLVM_LINK_LLVM_DYLIB=ON \
	-S llvm \
	-B native-build
$CMAKE_BIN --build native-build -- -j20

popd

# create symlink for llvm-config
info "creating symlinks for libLLVM (required by llvm-config)"
LLVM_CONFIG_SHARED_SO=libLLVM-21.so
pushd ${TARGET_ROOT}.llvm/${OHOS_LIBDIR}
if [ ! -f $LLVM_CONFIG_SHARED_SO ]; then
	ln -s libLLVM.so.21.1 $LLVM_CONFIG_SHARED_SO
fi
popd
pushd llvm/native-build/lib
if [ ! -f $LLVM_CONFIG_SHARED_SO ]; then
	ln -s libLLVM.so.21.1 $LLVM_CONFIG_SHARED_SO
fi
popd

# build llvm-config-wrapper
info "building CXX object llvm-config (cross compile) for native platform"
LLVM_CONFIG_WRAPPER_SRC=${CUR_DIR}/llvm-config-wrapper/llvm-config-wrapper.cpp
sed -i -e "s|\(static const std::string NATIVE_LLVM_CONFIG = \).*|\1\"${CUR_DIR}/llvm/native-build/bin/llvm-config\";|" \
	-e "s|\(static const std::string TARGET_LLVM_PREFIX = \).*|\1\"${TARGET_ROOT}.llvm\";|" \
	-e "s|\(static const std::string OHOS_LIBDIR = \).*|\1\"${OHOS_LIBDIR}\";|" \
	-e "s|\(static const std::string OHOS_CPU = \).*|\1\"${OHOS_CPU}\";|" \
	${LLVM_CONFIG_WRAPPER_SRC}
g++ -std=c++17 ${LLVM_CONFIG_WRAPPER_SRC} -o llvm-config-wrapper/llvm-config

# currently only clang & lld are needed
exit 0

COMPILE_FLAGS="-march=armv8-a"
cmake -S compiler-rt \
	-G Ninja \
	-DCMAKE_AR=${AR} \
	-DCMAKE_NM=${NM} \
	-DCMAKE_RANLIB=${RANLIB} \
	-DLLVM_CMAKE_DIR="${OHOS_SDK}/native/llvm/lib/cmake/llvm" \
	-DCMAKE_SYSROOT="${HOST_SYSROOT}" \
	-DCMAKE_ASM_COMPILER_TARGET="${TARGET}" \
	-DCMAKE_ASM_FLAGS="${COMPILE_FLAGS}" \
	-DCMAKE_C_COMPILER_TARGET="${TARGET}" \
	-DCMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN=${GCC_TOOLCHAIN} \
	-DCMAKE_C_COMPILER=${CC} \
	-DCMAKE_C_FLAGS="${COMPILE_FLAGS}" \
	-DCMAKE_CXX_COMPILER_TARGET="${TARGET_TRIPLE}" \
	-DCMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN=${GCC_TOOLCHAIN} \
	-DCMAKE_CXX_COMPILER=${CXX} \
	-DCMAKE_CXX_FLAGS="${COMPILE_FLAGS}" \
	-DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
	-DCOMPILER_RT_BUILD_BUILTINS=ON \
	-DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
	-DCOMPILER_RT_BUILD_MEMPROF=OFF \
	-DCOMPILER_RT_BUILD_PROFILE=OFF \
	-DCOMPILER_RT_BUILD_CTX_PROFILE=OFF \
	-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
	-DCOMPILER_RT_BUILD_XRAY=OFF \
	-DCOMPILER_RT_BUILD_ORC=OFF \
	-DCOMPILER_RT_BUILD_CRT=OFF \
	-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
	-DCOMPILER_RT_EMULATOR="qemu-arm -L ${SYSROOT}" \
	-DCOMPILER_RT_INCLUDE_TESTS=ON \
	-DCOMPILER_RT_TEST_COMPILER=${LLVM_TOOLCHAIN}/bin/clang \
	-DCOMPILER_RT_TEST_COMPILER_CFLAGS="--target=${TARGET_TRIPLE} ${COMPILE_FLAGS} --gcc-toolchain=${GCC_TOOLCHAIN} --sysroot=${SYSROOT} -fuse-ld=lld"

popd
#build_cmakeproj_with_deps "flann" "" "-DBUILD_SHARED_LIBS=ON"
#build_cmakeproj_with_deps "pcl" "eigen" "-DBUILD_SHARED_LIBS=ON"



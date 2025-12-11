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



pushd llvm

# build tools first
$CMAKE_BIN \
	-DCMAKE_TOOLCHAIN_FILE=../$TARGET-clang.cmake \
	-DLLVM_ENABLE_ASSERTIONS=OFF \
	-DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" \
	-DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
	-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
	-DLLVM_LINK_LLVM_DYLIB=ON \
	-DLLVM_TOOLCHAIN_TOOLS="llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-pdbutil;llvm-objcopy;llvm-strip;llvm-cov;llvm-profdata;llvm-addr2line;llvm-symbolizer;llvm-windres;llvm-ml;llvm-readelf;llvm-size;llvm-cxxfilt" \
	-DLLVM_HOST_TRIPLE=$TARGET \
	${COMP_FLAGS} \
	-S llvm \
	-B ohos-build
	#-DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86;NVPTX;PowerPC;RISCV" \
$CMAKE_BIN --build ohos-build -- -j10
$CMAKE_BIN --install ohos-build

# build native tools (OH toolchain broken: cannot find LLVMDemangle.a)
mkdir -p native-install
$CMAKE_BIN \
	-DCMAKE_INSTALL_PREFIX=native-install \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_VERBOSE_MAKEFILE=ON \
	-DLLVM_ENABLE_ASSERTIONS=OFF \
	-DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" \
	-DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
	-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
	-DLLVM_LINK_LLVM_DYLIB=ON \
	-DLLVM_TOOLCHAIN_TOOLS="llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-pdbutil;llvm-objcopy;llvm-strip;llvm-cov;llvm-profdata;llvm-addr2line;llvm-symbolizer;llvm-windres;llvm-ml;llvm-readelf;llvm-size;llvm-cxxfilt" \
	-DLLVM_HOST_TRIPLE=${BUILD_PLATFORM_TRIPLET} \
	-S llvm \
	-B native-build
$CMAKE_BIN --build native-build -- -j20
$CMAKE_BIN --install native-build

## FIXME: OH toolchain not support: LLVMDemangle.a lost
## build native runtime for profiling
#mkdir -p compiler-rt/native-build
#pushd compiler-rt/native-build
#$CMAKE_BIN \
#	-DCMAKE_BUILD_TYPE=Release \
#	-DCMAKE_INSTALL_PREFIX=${LLVM_RES_DIR} \
#	-DCMAKE_VERBOSE_MAKEFILE=ON \
#	-DCMAKE_C_COMPILER=clang \
#	-DCMAKE_CXX_COMPILER=clang++ \
#	-DCMAKE_FIND_ROOT_PATH=${LLVM_DIST} \
#	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
#	-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
#	-DCOMPILER_RT_USE_LIBCXX=OFF \
#	-DLLVM_CONFIG_PATH="" \
#	..
#$CMAKE_BIN --build . -j10
#$CMAKE_BIN --install .
#popd

mkdir -p compiler-rt/ohos-build
pushd compiler-rt/ohos-build
$CMAKE_BIN \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_VERBOSE_MAKEFILE=ON \
	-DCMAKE_INSTALL_PREFIX="${LLVM_RES_DIR}" \
	-DCMAKE_C_COMPILER=${CUR_DIR}/llvm/native-install/bin/clang \
	-DCMAKE_CXX_COMPILER=${CUR_DIR}/llvm/native-install/bin/clang++ \
	-DCMAKE_SYSTEM_NAME=OHOS \
	-DCMAKE_AR="${LLVM_DIST}/bin/llvm-ar" \
	-DCMAKE_RANLIB="${LLVM_DIST}/bin/llvm-ranlib" \
	-DCMAKE_C_FLAGS_INIT="$CFLAGS" \
	-DCMAKE_CXX_FLAGS_INIT="$CXXFLAGS" \
	-DCMAKE_EXE_LINKER_FLAGS="$COMMON_LINKER_FLAGS" \
	-DCMAKE_SHARED_LINKER_FLAGS="$COMMON_LINKER_FLAGS" \
	-DCMAKE_C_COMPILER_WORKS=1 \
	-DCMAKE_CXX_COMPILER_WORKS=1 \
	-DCMAKE_C_COMPILER_TARGET=${TARGET} \
	-DCMAKE_CXX_COMPILER_TARGET=${TARGET} \
	-DCMAKE_ASM_COMPILER_TARGET=${TARGET} \
	-DCOMPILER_RT_DEFAULT_TARGET_ARCH=${TARGET} \
	-DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
	-DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
	-DCOMPILER_RT_BUILD_BUILTINS=TRUE \
	-DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
	-DLLVM_CONFIG_PATH="" \
	-DCMAKE_FIND_ROOT_PATH=${LLVM_DIST} \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
	-DSANITIZER_CXX_ABI=libc++ \
	../lib/builtins
	#-DCMAKE_C_COMPILER_TARGET=${OHOS_CPU}-linux-musleabi \
	#-DCMAKE_CXX_COMPILER_TARGET=${OHOS_CPU}-linux-musleabi \
	#-DCMAKE_ASM_COMPILER_TARGET=${OHOS_CPU}-linux-musleabi \
$CMAKE_BIN --build . -j1
popd

exit 0


#$CMAKE_BIN \
#	-DCMAKE_TOOLCHAIN_FILE=../$TARGET-clang.cmake \
#	-DLLVM_TARGETS_TO_BUILD=all \
#	-DLLVM_ENABLE_PROJECTS="clang;flang;clang-tools-extra;lld;mlir;polly" \
#	-DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx;compiler-rt;openmp" \
#	-DLLVM_INSTALL_UTILS=ON \
#	${COMP_FLAGS} \
#	${CONF_FLAGS} \
#	-DCLANG_DEFAULT_CXX_STDLIB=libc++ \
#	-DCLANG_DEFAULT_RTLIB=compiler-rt \
#	-DCLANG_DEFAULT_UNWINDLIB=libunwind \
#	-DCLANG_DEFAULT_OPENMP_RUNTIME=libomp \
#	-DLIBCXX_CXX_ABI=libcxxabi \
#	-S llvm \
#	-B ohos-build
#read -p "check >>> "
#$CMAKE_BIN --build ohos-build -- -j20 clang lld opt mlir-libraries
#read -p "check >>> "
#$CMAKE_BIN --build ohos-build -- -j10 builtins flang flang-libraries
$CMAKE_BIN --install ohos-build 
exit 0
#read -p "check >>> "
# clear cmake cache
rm ohos-build/CMakeCache.txt
$CMAKE_BIN \
	-DCMAKE_TOOLCHAIN_FILE=../$TARGET-clang.cmake \
	-DLLVM_TARGETS_TO_BUILD=all \
	-DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;mlir;polly" \
	-DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx;compiler-rt;openmp" \
	-DLLVM_INSTALL_UTILS=ON \
	${COMP_FLAGS} \
	${CONF_FLAGS} \
	-DCLANG_DEFAULT_CXX_STDLIB=libc++ \
	-DCLANG_DEFAULT_RTLIB=compiler-rt \
	-DCLANG_DEFAULT_UNWINDLIB=libunwind \
	-DCLANG_DEFAULT_OPENMP_RUNTIME=libomp \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLLVM_ENABLE_EH=ON \
	-DLLVM_ENABLE_RTTI=ON \
	-S llvm \
	-B ohos-build
$CMAKE_BIN --build ohos-build -- -j10 compiler-rt cxx cxxabi
read -p "check >>> "
$CMAKE_BIN --build ohos-build -- -j10

exit 0

# build musl headers
#pushd musl
#mkdir -p ohos-build
#pushd ohos-build
#
#../configure \
#	--target=${TARGET} \
#	--prefix=${MUSL_DIST} \
#	--libdir="${MUSL_DIST}/${OHOS_LIBDIR}" \
#	--syslibdir="${MUSL_DIST}/lib" \
#	--disable-wrapper
#make -j10 install-headers
#
#popd
#popd

# TODO: install linux headers


# build compiler-rt builtin first
pushd llvm
$CMAKE_BIN \
	-S compiler-rt \
	-G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=${LLVM_DIST} \
	-DCMAKE_INSTALL_LIBDIR=${OHOS_LIBDIR} \
	-DLLVM_CMAKE_DIR="${LLVM_DIST}/${OHOS_LIBDIR}/cmake/llvm" \
	-DCMAKE_TOOLCHAIN_FILE=$(pwd)/$TARGET-clang.cmake \
	-DCMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN=${EXT_TOOLCHAIN_ROOT} \
	-DCMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN=${EXT_TOOLCHAIN_ROOT} \
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
	-DCOMPILER_RT_EMULATOR="qemu-${OHOS_CPU} -L ${SYSROOT}" \
	-DCOMPILER_RT_INCLUDE_TESTS=ON \
	-DCOMPILER_RT_TEST_COMPILER=${LLVM_DIST}/bin/clang \
	-DCOMPILER_RT_TEST_COMPILER_CFLAGS="--target=${TARGET} --gcc-toolchain=${EXT_TOOLCHAIN_ROOT} --sysroot=${HOST_SYSROOT} -fuse-ld=lld" \
	-B ohos-rt-build
	#-DCMAKE_ASM_FLAGS="--target=${OHOS_CPU}-linux-ohos" \
        #-DCMAKE_FIND_ROOT_PATH= \
        #-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        #-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
pushd ohos-rt-build
ninja builtins
#ninja check-builtins
popd

#build_cmakeproj_with_deps "flann" "" "-DBUILD_SHARED_LIBS=ON"
#build_cmakeproj_with_deps "pcl" "eigen" "-DBUILD_SHARED_LIBS=ON"



#!/bin/bash

. setup.sh

pushd OpenBLAS
if [[ ! -f patched ]]; then
    echo "#include <stdlib.h>\n$(cat utest/test_extensions/common.c)" > utest/test_extensions/common.c
    patch -N driver/others/blas_server.c < ${CUR_DIR}/patches/oh-openblas-blasserver.patch >&2
    patch -N cblas.h < ${CUR_DIR}/patches/oh-openblas-cblas.patch >&2
    touch patched
fi
popd

build_cmakeproj_with_deps "OpenBLAS" "" "-DBUILD_SHARED_LIBS=ON"


# makeproj build method

## patch for libdir
#sed -i "s|^OPENBLAS_LIBRARY_DIR := \$(PREFIX)/lib$|OPENBLAS_LIBRARY_DIR := \$(PREFIX)/${OHOS_LIBDIR}|g" Makefile.install
## NOTE: Add TARGET=ARMV8 manually if $OHOS_CPU==aarch64
#MAKE_FLAGS=(BINARY=64 CC="$CC" FC="$FC" CROSS=1 HOSTCC=gcc VERBOSE=1 NOFORTRAN=1)
#if [ "$OHOS_CPU" == "aarch64" ]; then
#	MAKE_FLAGS+=(TARGET=ARMV8)
#elif [ "$OHOS_CPU" == "arm" ]; then
#	MAKE_FLAGS+=(TARGET=ARMV7)
#fi
##../test-param.sh "${MAKE_FLAGS[@]}"
#
## expand as separate words, preserving the CC value as one word even if it contains spaces/options
#make "${MAKE_FLAGS[@]}"
#make install PREFIX=${TARGET_ROOT}
#popd
#mv ${TARGET_ROOT} ${TARGET_ROOT}.openblas
#patch_libdir_origin "openblas"

. cleanup.sh


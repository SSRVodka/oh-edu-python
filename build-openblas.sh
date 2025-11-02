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

# cmakeproj build method

#_openblas_target=""
#if [ "$OHOS_CPU" == "aarch64" ]; then
#	_openblas_target="ARMV8"
#elif [ "$OHOS_CPU" == "arm" ]; then
#	_openblas_target="ARMV7"
#elif [ "$OHOS_CPU" == "x86_64" ]; then
#	_openblas_target="generic"
#fi
#
#build_cmakeproj_with_deps "OpenBLAS" "" "-DBUILD_SHARED_LIBS=ON -DTARGET=${_openblas_target}"


# makeproj build method

pushd OpenBLAS
# patch for libdir
sed -i "\|${OHOS_LIBDIR}|! s|^OPENBLAS_LIBRARY_DIR := \$(PREFIX)/lib$|OPENBLAS_LIBRARY_DIR := \$(PREFIX)/${OHOS_LIBDIR}|g" Makefile.install
# NOTE: Add TARGET=ARMV8 manually if $OHOS_CPU==aarch64
MAKE_FLAGS=(BINARY=64 CC="$CC" FC="${FC:-}" CROSS=1 HOSTCC=gcc VERBOSE=1 NOFORTRAN=1)
if [ "$OHOS_CPU" == "aarch64" ]; then
	MAKE_FLAGS+=(TARGET=ARMV8)
elif [ "$OHOS_CPU" == "arm" ]; then
	MAKE_FLAGS+=(TARGET=ARMV7)
#elif [ "$OHOS_CPU" == "x86_64" ]; then
#	MAKE_FLAGS+=(TARGET=generic)
fi
#../test-param.sh "${MAKE_FLAGS[@]}"

# expand as separate words, preserving the CC value as one word even if it contains spaces/options
make "${MAKE_FLAGS[@]}"
make install PREFIX=${TARGET_ROOT}
popd
mv ${TARGET_ROOT} ${TARGET_ROOT}.OpenBLAS
patch_libdir_origin "OpenBLAS"

. cleanup.sh


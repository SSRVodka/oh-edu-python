#!/bin/bash

. setup.sh

cd OpenBLAS
if [[ ! -f patched ]]; then
    echo "#include <stdlib.h>\n$(cat utest/test_extensions/common.c)" > utest/test_extensions/common.c
    patch -N driver/others/blas_server.c < ${CUR_DIR}/patches/oh-openblas-blasserver.patch >&2
    patch -N cblas.h < ${CUR_DIR}/patches/oh-openblas-cblas.patch >&2
    touch patched
fi
# NOTE: Add TARGET=ARMV8 manually if $OHOS_CPU==aarch64
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

. cleanup.sh


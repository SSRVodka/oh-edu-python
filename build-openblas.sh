#!/bin/bash

. setup.sh

# NOTE: Add TARGET=ARMV8 manually if $OHOS_CPU==aarch64
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

. cleanup.sh


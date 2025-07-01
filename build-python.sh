#!/bin/bash
set -Eeuo pipefail

################################# Build build-python first! #################################

# NOTE: keep same with setup.sh
BUILD_PYTHON_DIST=$(dirname $(readlink -f $0))/build-python.dist

echo "Set Build-Python Destination: ${BUILD_PYTHON_DIST}"

cd BPython
./configure \
	--prefix=${BUILD_PYTHON_DIST} \
	--enable-shared
make -j
make install
cd ..

################################# Setup Envs #################################


. setup.sh

if [ "$DOWNLOAD" -eq 1 ]; then
    ./download-python.sh
fi

################################# Build Python Dependencies #################################

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


################################# Build Python And Patch #################################


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
_LOST_LIBRARY=libpython${PY_VERSION}.so
_DIST_LIB_DYLOAD_PATH=${TARGET_ROOT}/lib/python${PY_VERSION}/lib-dynload
find "${_DIST_LIB_DYLOAD_PATH}" -type f -name "*.so" -print0 | while IFS= read -r -d '' sofile; do
    info "patch dynamic-linked file: $sofile"
    if ! patchelf --add-needed "${_LOST_LIBRARY}" "$sofile"; then
        error "failed to process file $sofile"
    fi
done


. cleanup.sh

#!/bin/bash
# WARNING: this file should only be used & called by ohos-build.sh

export PKG_CONFIG_PATH=${TARGET_ROOT}/lib/pkgconfig
export PKG_CONFIG_LIBDIR=${TARGET_ROOT}/lib:${TARGET_ROOT}/ssl/lib64:${OHOS_SDK}/native/sysroot/usr/lib/${OHOS_CPU}-linux-ohos

cd libaacplus
CFLAGS="${CFLAGS} -std=gnu89" ./autogen.sh --target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--enable-static \
	--prefix=${TARGET_ROOT} \
    ac_cv_file__bin_bash=no
make
make install
cd ..

cd x264
./configure --target=${OHOS_CPU}-linux-musl \
    --host=${OHOS_CPU}-linux-musl \
    --build=x86_64-pc-linux-gnu \
    --prefix=${TARGET_ROOT} \
    --disable-asm \
    --enable-pic \
    --enable-shared
make -j
make install
cd ..

cd alsa-lib
# patch versionsort64
find . -name "*.c" -type f -exec sed -i 's/^#if defined(_GNU_SOURCE) \&\& !defined(__NetBSD__) \&\& !defined(__FreeBSD__) \&\& !defined(__OpenBSD__) \&\& !defined(__DragonFly__) \&\& !defined(__sun) \&\& !defined(__ANDROID__)$/#if defined(_GNU_SOURCE) \&\& !defined(__NetBSD__) \&\& !defined(__FreeBSD__) \&\& !defined(__OpenBSD__) \&\& !defined(__DragonFly__) \&\& !defined(__sun) \&\& !defined(__ANDROID__) \&\& !defined(__OPENHARMONY__)/g' {} \;
./configure --target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--prefix=${TARGET_ROOT}
make -j
make install
cd ..

cd ffmpeg
./configure --enable-cross-compile \
    --arch="${OHOS_ARCH}" \
    --nm="${NM}" \
    --ar="${AR}" \
    --as="${AS}" \
    --strip="${STRIP}" \
    --cc="${CC}" \
    --cxx="${CXX}" \
    --ld="${CC}" \
    --ranlib="${RANLIB}" \
    --enable-pic \
	--prefix="${TARGET_ROOT}" \
    --enable-gpl \
    --enable-nonfree \
    --extra-libs=-ldl
make -j
make install
unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR
cd ..

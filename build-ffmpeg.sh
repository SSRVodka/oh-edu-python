#!/bin/bash

_FFMPEG_BACKUP_PKG_CONFIG_PATH=${PKG_CONFIG_PATH}
_FFMPEG_BACKUP_PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR}

. setup.sh

# override config in setup.sh
export PKG_CONFIG_PATH=${TARGET_ROOT}/lib/pkgconfig:${_FFMPEG_BACKUP_PKG_CONFIG_PATH}
export PKG_CONFIG_LIBDIR=${TARGET_ROOT}/lib:${TARGET_ROOT}/ssl/lib64:${_FFMPEG_BACKUP_PKG_CONFIG_LIBDIR}


pushd libaacplus
CFLAGS="${CFLAGS} -std=gnu89" ./autogen.sh --target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--enable-static \
	--prefix=${TARGET_ROOT} \
    ac_cv_file__bin_bash=no
make
make install
popd

pushd x264
./configure --target=${OHOS_CPU}-linux-musl \
    --host=${OHOS_CPU}-linux-musl \
    --build=x86_64-pc-linux-gnu \
    --prefix=${TARGET_ROOT} \
    --disable-asm \
    --enable-pic \
    --enable-shared
make -j
make install
popd

pushd alsa-lib
# patch versionsort64
find . -name "*.c" -type f -exec sed -i 's/^#if defined(_GNU_SOURCE) \&\& !defined(__NetBSD__) \&\& !defined(__FreeBSD__) \&\& !defined(__OpenBSD__) \&\& !defined(__DragonFly__) \&\& !defined(__sun) \&\& !defined(__ANDROID__)$/#if defined(_GNU_SOURCE) \&\& !defined(__NetBSD__) \&\& !defined(__FreeBSD__) \&\& !defined(__OpenBSD__) \&\& !defined(__DragonFly__) \&\& !defined(__sun) \&\& !defined(__ANDROID__) \&\& !defined(__OPENHARMONY__)/g' {} \;
./configure --target=${OHOS_CPU}-linux-musl \
	--host=${OHOS_CPU}-linux-musl \
	--build=x86_64-pc-linux-gnu \
	--prefix=${TARGET_ROOT}
make -j
make install
popd

pushd ffmpeg
if [[ ! -f patched ]]; then
    patch -N configure < ${CUR_DIR}/patches/oh-ffmpeg.patch >&2
    touch patched
fi
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
    --enable-shared \
    --extra-libs=-ldl
make -j
make install
popd


. cleanup.sh

export PKG_CONFIG_PATH=${_FFMPEG_BACKUP_PKG_CONFIG_PATH}
export PKG_CONFIG_LIBDIR=${_FFMPEG_BACKUP_PKG_CONFIG_LIBDIR}


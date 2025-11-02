#!/bin/bash

. setup.sh

_pre_aac_cflags="${CFLAGS}"
CFLAGS="${CFLAGS} -std=gnu89"
# patch https to avoid 301
sed -i 's|http://\(.\+\)|https://\1|' libaacplus/src/Makefile.am
# WARN: cannot use -j option
build_makeproj_with_deps "libaacplus" "" "--enable-static" "" "ac_cv_file__bin_bash=no" "1"
CFLAGS="${_pre_aac_cflags}"

build_makeproj_with_deps "x264" "" "--disable-asm --enable-pic --enable-shared"

# patch versionsort64
find alsa-lib -name "*.c" -type f -exec sed -i 's/^#if defined(_GNU_SOURCE) \&\& !defined(__NetBSD__) \&\& !defined(__FreeBSD__) \&\& !defined(__OpenBSD__) \&\& !defined(__DragonFly__) \&\& !defined(__sun) \&\& !defined(__ANDROID__)$/#if defined(_GNU_SOURCE) \&\& !defined(__NetBSD__) \&\& !defined(__FreeBSD__) \&\& !defined(__OpenBSD__) \&\& !defined(__DragonFly__) \&\& !defined(__sun) \&\& !defined(__ANDROID__) \&\& !defined(__OPENHARMONY__)/g' {} \;
build_makeproj_with_deps "alsa-lib"

build_makeproj_with_deps "libiconv" "" "--with-sysroot=${HOST_SYSROOT}"


pushd ffmpeg
if [[ ! -f patched ]]; then
    patch -N configure < ${CUR_DIR}/patches/oh-ffmpeg.patch >&2
    touch patched
fi
_ff_deps="zlib xz libaacplus x264 libiconv"
_ff_libdir=${TARGET_ROOT}/${OHOS_LIBDIR}

_pre_ff_cc="$CC"
_pre_ff_cxx="$CXX"
_pre_ff_cflags="${CFLAGS}"
_pre_ff_ldflags="${LDFLAGS}"
_pre_ff_pkgconfig_libdir="$PKG_CONFIG_LIBDIR"
for dep in $_ff_deps; do
	CFLAGS="$CFLAGS -I${TARGET_ROOT}.${dep}/include"
	LDFLAGS="$LDFLAGS -L${TARGET_ROOT}.${dep}/${OHOS_LIBDIR}"
	PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:${TARGET_ROOT}.${dep}/${OHOS_LIBDIR}/pkgconfig"
done
CFLAGS="${CFLAGS} --target=${OHOS_CPU}-linux-ohos"
CXXFLAGS="${CFLAGS}"
ASFLAGS="--target=${OHOS_CPU}-linux-ohos"
CPPFLAGS="${CFLAGS}"
# ffmpeg doesn't support CC hack so we use original CC
CC=${OHOS_SDK}/native/llvm/bin/clang
CXX=${OHOS_SDK}/native/llvm/bin/clang++

./configure --enable-cross-compile \
    --cpu="generic" \
    --arch="${OHOS_CPU}" \
    --nm="${NM}" \
    --ar="${AR}" \
    --strip="${STRIP}" \
    --cc="${CC}" \
    --cxx="${CXX}" \
    --ld="${CC} --target=${OHOS_CPU}-linux-ohos" \
    --ranlib="${RANLIB}" \
    --enable-pic \
    --prefix="${TARGET_ROOT}" \
    --libdir="${_ff_libdir}" \
    --enable-gpl \
    --enable-nonfree \
    --enable-shared \
    --enable-version3 \
    --enable-libx264 \
    --extra-libs=-ldl
    # cannot use llvm-as. Use clang instead
    #--as="${AS}" \
make -j
make install
popd

mv ${TARGET_ROOT} ${TARGET_ROOT}.ffmpeg
patch_libdir_origin "ffmpeg"

CFLAGS="$_pre_ff_cflags"
CXXFLAGS="${CFLAGS}"
CPPFLAGS="${CFLAGS}"
LDFLAGS="$_pre_ff_ldflags"
PKG_CONFIG_LIBDIR="$_pre_ff_pkgconfig_libdir"

. cleanup.sh


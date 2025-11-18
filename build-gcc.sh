#!/bin/bash

. setup.sh

build_makeproj_with_deps "gmp"
build_makeproj_with_deps "mpfr" "gmp"
build_makeproj_with_deps "mpc" "gmp mpfr"
build_makeproj_with_deps "binutils" "" "--enable-install-libiberty"
build_makeproj_with_deps "patchelf" "" "" "./bootstrap.sh"

# already built in python
#build_makeproj_with_deps "gettext" "" "--enable-shared"

#CFLAGS="${CFLAGS} -I${OHOS_SDK}/native/llvm/include/libcxx-ohos/include/c++/v1"
#CFLAGS="${CFLAGS} -I${OHOS_SDK}/native/llvm/include/c++/v1"
#CXXFLAGS="${CFLAGS} -std=gnu++11"
#CPPFLAGS="${CFLAGS}"
#not trying to build gcc stage1: too complicated for OH's gn
#build_makeproj_with_deps "gcc" "gmp mpfr mpc binutils gettext zlib" "--disable-libstdcxx --disable-bootstrap --disable-libsanitizer --enable-languages=c --without-headers --disable-multilib --with-sysroot=${HOST_SYSROOT}" "" "" "1"
#build_makeproj_with_deps "gcc" "gmp mpfr mpc binutils gettext zlib" "--enable-default-pie --enable-default-ssp --enable-host-pie --disable-libstdcxx --disable-bootstrap --disable-libsanitizer --enable-languages=fortran --with-sysroot=${HOST_SYSROOT}" "" "" "1"

#error here: freadahead.c:101:3: error: "Please port gnulib freadahead.c to your platform! Look at the definition of fflush, fread, ungetc on your system, then report this to bug-gnulib."
#build_makeproj_with_deps "m4"



#!/bin/bash
# build this only after build-python.sh and build-pypkg-numpy-and-scipy.sh and build-gui.sh

. setup-pypkg-env.sh

# more dependencies for numpy
_np_deps="OpenBLAS"
for _np_dep in $_np_deps; do
	CFLAGS="-I${TARGET_ROOT}.${_np_dep}/include ${CFLAGS}"
	LDFLAGS="-L${TARGET_ROOT}.${_np_dep}/${OHOS_LIBDIR} ${LDFLAGS}"
	PKG_CONFIG_LIBDIR="${TARGET_ROOT}.${_np_dep}/${OHOS_LIBDIR}/pkgconfig:${PKG_CONFIG_LIBDIR}"
done
# update meson
set_meson_list "meson-scripts/ohos-build.meson" "common_c_flags" "$CFLAGS"
set_meson_list "meson-scripts/ohos-build.meson" "common_ld_flags" "$LDFLAGS"

################################## Build Pybullet ##################################

info "building bullet3..."

# patches
# patch for pthread_getconcurrency
sed -i '\|__OPENHARMONY__|! s|^\(#if !defined(__NetBSD__) \&\& !defined(__ANDROID__)\)|\1 \&\& !defined(__OPENHARMONY__)|' bullet3/examples/OpenGLWindow/X11OpenGLWindow.cpp
# patch for ohos link
sed -i '\|python|! s|^\(TARGET_LINK_LIBRARIES(pybullet[[:space:]]*\)\(BulletRoboticsGUI.*\)$|\1python3.12 \2|' bullet3/examples/pybullet/CMakeLists.txt
# why it will build shared lib without STATIC even STATIC is default? We don't know :(
sed -i '\|STATIC|! s|^\(ADD_LIBRARY(gwen[[:space:]]*\)\(.*)\)$|\1STATIC \2|' bullet3/examples/ThirdPartyLibs/Gwen/CMakeLists.txt
_bullet_libsuffix="${OHOS_LIBDIR#*/}"
_bullet_extflag=""
if [ ! "$_bullet_libsuffix" == "${OHOS_LIBDIR}" ]; then
	_bullet_extflag="-DLIB_SUFFIX=/${_bullet_libsuffix}"
fi
# deps: glu mesa xorg python
# not support libdir
build_cmakeproj_with_deps "bullet3" "glu mesa xorg Python" \
	"\
	${_bullet_extflag} \
	-DBUILD_PYBULLET=ON \
	-DBUILD_PYBULLET_NUMPY=ON \
	-DUSE_DOUBLE_PRECISION=ON \
	-DBT_USE_EGL=ON \
	-DPYTHON_INCLUDE_DIR=${TARGET_ROOT}.Python/include/python${PY_VERSION} \
	-DPYTHON_LIBRARY=${TARGET_ROOT}.Python/${OHOS_LIBDIR}/libpython3.so \
	-DPYTHON_NUMPY_INCLUDE_DIR=${NUMPY_LIBROOT}/include \
	-DPYTHON_NUMPY_VERSION=${NUMPY_VERSION} \
	" \
	"" \
	"" \
	"" \
	"" \
	"20"

if [ ! "${OHOS_LIBDIR}" == "lib" ]; then
	# remove arch-dependent libs not in ${OHOS_LIBDIR} (also useless)
	rm -f ${TARGET_ROOT}.bullet3/lib/libclsocket.a
fi

# TODO: fix rubbish pybullet setup.py


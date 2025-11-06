#!/bin/bash


DOWNLOAD=0
while getopts "d" arg
do
    case $arg in
    d)
        DOWNLOAD=1
        ;;
    ?)
        warn "Unknown argument: $arg. Ignored."
        ;;
    esac
done

if [ "$DOWNLOAD" -eq 1 ]; then
    ./download-pypkgs.sh
fi

_PYPKG_ENV_BACKUP_LD_LIBRARY_PATH=${LD_LIBRARY_PATH}
_PYPKG_ENV_BACKUP_PKG_CONFIG_PATH=${PKG_CONFIG_PATH}
_PYPKG_ENV_BACKUP_PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR}

. setup.sh

# override config in setup.sh
export LD_LIBRARY_PATH=${BUILD_PYTHON_DIST}/lib:$LD_LIBRARY_PATH


# Numpy version >= 2.0
NUMPY_GT_V2=1
if [ $NUMPY_GT_V2 -eq 0 ]; then
    NUMPY_LIBROOT=${HOST_SITE_PKGS}/numpy/core
else
    NUMPY_LIBROOT=${HOST_SITE_PKGS}/numpy/_core
fi


################################# Setup building flags #################################


# override the flags (python deps) in setup.sh
_pypkg_deps="$PY_DEPS Python"
for dep in $_pypkg_deps; do
	CFLAGS="-I${TARGET_ROOT}.${dep}/include $CFLAGS"
	LDFLAGS="-L${TARGET_ROOT}.${dep}/${OHOS_LIBDIR} $LDFLAGS"
	PKG_CONFIG_LIBDIR="${TARGET_ROOT}.${dep}/${OHOS_LIBDIR}/pkgconfig:${PKG_CONFIG_LIBDIR}"
done

# add header path for special libraries (python deps & numpy-dev)
CFLAGS="-I${TARGET_ROOT}.xz/include/lzma -I${TARGET_ROOT}.ncurses/include/ncursesw -I${TARGET_ROOT}.readline/include/readline -I${TARGET_ROOT}.util-linux/include/uuid -I${NUMPY_LIBROOT}/include $CFLAGS"
CXXFLAGS="$CFLAGS"
LDFLAGS="-lpython${PY_VERSION} -L${NUMPY_LIBROOT}/lib $LDFLAGS"
PKG_CONFIG_LIBDIR="${HOST_PYTHON_DIST}/${OHOS_LIBDIR}/pkgconfig:${NUMPY_LIBROOT}/lib/pkgconfig"
# export PKG_CONFIG_SYSROOT_DIR=${OHOS_SDK}/native/sysroot
# export PKG_CONFIG_PATH=${HOST_PYTHON_DIST}/${OHOS_LIBDIR}/pkgconfig:${NUMPY_LIBROOT}/lib/pkgconfig
# Use PKG_CONFIG_SYSTEM_IGNORE_PATH in setup.sh

# setup flags in meson scripts
for ms_sh in "${CUR_DIR}/meson-scripts"/*.meson; do
	set_meson_list $ms_sh "common_c_flags" "$CFLAGS"
	set_meson_list $ms_sh "common_ld_flags" "$LDFLAGS"
done

################################## Setup crossenv ##################################


if [[ ! -d ${PY_CROSS_ROOT} ]]; then
    $BUILD_PIP install crossenv
    $BUILD_PYTHON -m crossenv \
        $HOST_PYTHON \
        crossenv_${OHOS_CPU}
fi

CROSS_ROOT=${CUR_DIR}/crossenv_${OHOS_CPU}
. ${CROSS_ROOT}/bin/activate



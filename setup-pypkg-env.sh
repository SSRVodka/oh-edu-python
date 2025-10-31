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


# NOTE: You also need to change download-pypkgs.sh if you change this
# Numpy version >= 2.0
NUMPY_GT_V2=1
if [ $NUMPY_GT_V2 -eq 0 ]; then
    NUMPY_LIBROOT=${HOST_SITE_PKGS}/numpy/core
else
    NUMPY_LIBROOT=${HOST_SITE_PKGS}/numpy/_core
fi

#export PKG_CONFIG_SYSROOT_DIR=${OHOS_SDK}/native/sysroot
export PKG_CONFIG_PATH=${HOST_PYTHON_DIST}/lib/pkgconfig:${NUMPY_LIBROOT}/lib/pkgconfig
export PKG_CONFIG_LIBDIR=${HOST_PYTHON_DIST}/lib:${HOST_SYSROOT}/usr/${OHOS_LIBDIR}:${NUMPY_LIBROOT}/lib
# Use PKG_CONFIG_SYSTEM_IGNORE_PATH in setup.sh


################################## Setup crossenv ##################################


if [[ ! -d ${PY_CROSS_ROOT} ]]; then
    $BUILD_PIP install crossenv
    $BUILD_PYTHON -m crossenv \
        $HOST_PYTHON \
        crossenv_${ARCH}
fi

CROSS_ROOT=${CUR_DIR}/crossenv_${ARCH}
. ${CROSS_ROOT}/bin/activate



#!/bin/bash

_PYPKG_ENV_BACKUP_LD_LIBRARY_PATH=${LD_LIBRARY_PATH}
_PYPKG_ENV_BACKUP_PKG_CONFIG_PATH=${PKG_CONFIG_PATH}
_PYPKG_ENV_BACKUP_PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR}

. setup.sh

if [ "$DOWNLOAD" -eq 1 ]; then
    ./download-pypkgs.sh
fi

# override config in setup.sh
export LD_LIBRARY_PATH=${BUILD_PYTHON_DIST}/lib:$LD_LIBRARY_PATH


NUMPY_GT_V2=0
# Numpy version >= 2.0
# NUMPY_LIBROOT=${HOST_SITE_PKGS}/numpy/_core
NUMPY_LIBROOT=${HOST_SITE_PKGS}/numpy/core

#export PKG_CONFIG_SYSROOT_DIR=${OHOS_SDK}/native/sysroot
export PKG_CONFIG_PATH=${HOST_PYTHON_DIST}/lib/pkgconfig:${NUMPY_LIBROOT}/lib/pkgconfig
export PKG_CONFIG_LIBDIR=${HOST_PYTHON_DIST}/lib:${HOST_SYSROOT}/usr/lib/${ARCH}-linux-ohos:${NUMPY_LIBROOT}/lib
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



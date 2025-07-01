#!/bin/bash
set -Eeuo pipefail

if [ -z "$OHOS_SDK" ]; then
	echo "[TIPS] please set OHOS_SDK env first"
	exit 0
fi

OLD_LD_LIBPATH=${LD_LIBRARY_PATH:=""}
trap "export LD_LIBRARY_PATH=${OLD_LD_LIBPATH}; unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR PKG_CONFIG_SYSTEM_IGNORE_PATH" ERR SIGINT SIGTERM

p_DIR=$(dirname $(readlink -f $0))
cd $p_DIR

ARCH=x86_64
#ARCH=aarch64

# modify ARCH in meson config
sed -i "s/x86_64/${ARCH}/g" ohos-build.meson
sed -i "s/aarch64/${ARCH}/g" ohos-build.meson
sed -i "s/x86_64/${ARCH}/g" scipy-build.meson
sed -i "s/aarch64/${ARCH}/g" scipy-build.meson

BUILD_PYTHON_DIST=${p_DIR}/../oh-edu-python/build-python.dist
HOST_PYTHON_DIST=${p_DIR}/../oh-edu-python/dist.${ARCH}

export LD_LIBRARY_PATH=${BUILD_PYTHON_DIST}/lib:$LD_LIBRARY_PATH

BUILD_PYTHON_BIN="${BUILD_PYTHON_DIST}/bin"
BUILD_PYTHON=$BUILD_PYTHON_BIN/python3
BUILD_PIP=$BUILD_PYTHON_BIN/pip3

HOST_PYTHON_BIN="${HOST_PYTHON_DIST}/bin"
HOST_PYTHON=$HOST_PYTHON_BIN/python3
HOST_PIP=$HOST_PYTHON_BIN/pip3
HOST_MESON=$HOST_PYTHON_BIN/meson

HOST_SYSROOT=${OHOS_SDK}/native/sysroot
HOST_SITE_PKGS=${p_DIR}/crossenv_${ARCH}/cross/lib/python3.11/site-packages

$BUILD_PIP install crossenv
$BUILD_PYTHON -m crossenv \
	$HOST_PYTHON \
	crossenv_${ARCH}
CROSS_ROOT=$(pwd)/crossenv_${ARCH}
. ${CROSS_ROOT}/bin/activate

# MUST use cython for cross-python
cd cython
pip install -v --no-binary :all: .
cd ..

pip install -v --no-binary :all: build

#build-pip install meson-python
cd numpy
rm -rf ./dist
export PKG_CONFIG_PATH=${HOST_PYTHON_DIST}/lib/pkgconfig
export PKG_CONFIG_LIBDIR=${HOST_PYTHON_DIST}/lib:${HOST_SYSROOT}/usr/lib/${ARCH}-linux-ohos
export PKG_CONFIG_SYSTEM_IGNORE_PATH=/usr/local/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig
#VENDORED_MESON=${p_DIR}/numpy/vendored-meson/meson/meson.py
#python ${VENDORED_MESON} setup --reconfigure --prefix=${p_DIR}/xdist51 --cross-file ../ohos-build.meson xbuild-ohos
#cd xbuild-ohos
#python ${VENDORED_MESON} compile --verbose
#python ${VENDORED_MESON} install
#cd ..
python -m build --wheel -Csetup-args="--cross-file=${p_DIR}/ohos-build.meson"
pip install -v ./dist/*.whl
cd ..

# use build-python (in crossenv) f2py: see scipy/scipy/meson.build#L203
build-pip install -v numpy pybind11
# use dependency numpy at cross-python
pip install -v pythran
cd scipy
rm -rf ./dist
#export PKG_CONFIG_SYSROOT_DIR=${OHOS_SDK}/native/sysroot
export PKG_CONFIG_PATH=${HOST_PYTHON_DIST}/lib/pkgconfig:${HOST_SITE_PKGS}/numpy/_core/lib/pkgconfig
export PKG_CONFIG_LIBDIR=${HOST_PYTHON_DIST}/lib:${HOST_SYSROOT}/usr/lib/${ARCH}-linux-ohos:${HOST_SITE_PKGS}/numpy/_core/lib
# patch meson.build for fortran link arguments
find . -type f -name "meson.build" -exec sed -i "s/link_language: 'fortran'/link_language: 'cpp'/g" {} \;
sed -i "s|version_link_args = \['-Wl,--version-script=' + _linker_script\]|version_link_args = ['--target=${ARCH}-linux-ohos', '--sysroot=${OHOS_SDK}/native/sysroot', '-lgfortran', '-Wl,--version-script=' + _linker_script]|" meson.build
## use normal meson
#meson setup --reconfigure --prefix=${p_DIR}/adist51 --cross-file ../scipy-build.meson xbuild-ohos
#cd xbuild-ohos
#meson compile --verbose
#meson install
#cd ..
python -m build --wheel -Csetup-args="--cross-file=${p_DIR}/scipy-build.meson"
pip install -v ./dist/*.whl
unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR PKG_CONFIG_SYSTEM_IGNORE_PATH
cd ..

export LD_LIBRARY_PATH=${OLD_LD_LIBPATH}


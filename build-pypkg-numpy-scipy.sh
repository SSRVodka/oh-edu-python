#!/bin/bash
# Build numpy and scipy
# Note: it must be called after build-python.sh is executed

. setup-pypkg-env.sh

# more dependencies for numpy, scipy
_np_deps="OpenBLAS"
for _np_dep in $_np_deps; do
	CFLAGS="-I${TARGET_ROOT}.${_np_dep}/include ${CFLAGS}"
	LDFLAGS="-L${TARGET_ROOT}.${_np_dep}/${OHOS_LIBDIR} ${LDFLAGS}"
	PKG_CONFIG_LIBDIR="${TARGET_ROOT}.${_np_dep}/${OHOS_LIBDIR}/pkgconfig:${PKG_CONFIG_LIBDIR}"
done
# update meson
set_meson_list "meson-scripts/ohos-build.meson" "common_c_flags" "$CFLAGS"
set_meson_list "meson-scripts/ohos-build.meson" "common_ld_flags" "$LDFLAGS"


################################## Build Dependencies For NumPy ##################################

info "building dependencies for NumPy..."

# MUST use cython for cross-python
pushd cython
pip install -v --no-binary :all: .
popd

# install pypi-build for cross-python
pip install -v --no-binary :all: build

#build-pip install meson-python

################################## Build NumPy ##################################

info "building NumPy..."

_NUMPY_DIR=numpy2
if [ $NUMPY_GT_V2 -eq 0 ]; then
	_NUMPY_DIR=numpy
fi

pushd $_NUMPY_DIR
rm -rf ./dist
#VENDORED_MESON=${CUR_DIR}/numpy/vendored-meson/meson/meson.py
#python ${VENDORED_MESON} setup --reconfigure --prefix=${CUR_DIR}/xdist51 --cross-file ../meson-scripts/ohos-build.meson xbuild-ohos
#cd xbuild-ohos
#python ${VENDORED_MESON} compile --verbose
#python ${VENDORED_MESON} install
#cd ..
python -m build --wheel -Csetup-args="--cross-file=${CUR_DIR}/meson-scripts/ohos-build.meson"
pip install -v ./dist/*-cp${PY_VERSION_CODE}-cp${PY_VERSION_CODE}-linux_${OHOS_CPU}.whl
popd

info "not building scipy for now! Reason: using GPL-licensed gfortran"
cp $_NUMPY_DIR/dist/* ${PYPKG_OUTPUT_WHEEL_DIR}
exit 0

################################## Build Dependencies For SciPy ##################################

info "building dependencies for SciPy..."

# use build-python (in crossenv) f2py: see scipy/scipy/meson.build#L203
build-pip install -v numpy pybind11
# use dependency numpy at cross-python
pip install -v pythran


################################## Build SciPy ##################################

info "building SciPy..."

info "PKG_CONFIG_PATH=${PKG_CONFIG_PATH}"
info "PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR}"
info "PKG_CONFIG_SYSTEM_IGNORE_PATH=${PKG_CONFIG_SYSTEM_IGNORE_PATH}"

cd scipy
rm -rf ./dist
# patch meson.build for fortran link arguments
find . -type f -name "meson.build" -exec sed -i "s/link_language: 'fortran'/link_language: 'cpp'/g" {} \;
sed -i "s|version_link_args = \['-Wl,--version-script=' + _linker_script\]|version_link_args = ['--target=${ARCH}-linux-ohos', '--sysroot=${OHOS_SDK}/native/sysroot', '-lgfortran', '-Wl,--version-script=' + _linker_script]|" meson.build
## use normal meson
#meson setup --reconfigure --prefix=${CUR_DIR}/adist51 --cross-file ../meson-scripts/scipy-build.meson xbuild-ohos
#cd xbuild-ohos
#meson compile --verbose
#meson install
#cd ..
if [ $NUMPY_GT_V2 -eq 0 ]; then
    python -m build --wheel -Csetup-args="--cross-file=${CUR_DIR}/meson-scripts/scipy-build.meson"
else
    python -m build --wheel -Csetup-args="--cross-file=${CUR_DIR}/meson-scripts/scipy-build.numpy2.meson"
fi
pip install -v ./dist/*.whl
cd ..

cp $_NUMPY_DIR/dist/* ${PYPKG_OUTPUT_WHEEL_DIR}
cp scipy/dist/* ${PYPKG_OUTPUT_WHEEL_DIR}


. cleanup-pypkg-env.sh


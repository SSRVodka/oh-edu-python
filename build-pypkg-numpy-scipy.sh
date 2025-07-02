#!/bin/bash
# Build numpy and scipy
# Note: it must be called after build-python.sh is executed

. setup-pypkg-env.sh

################################## Build Dependencies For NumPy ##################################

info "building dependencies for NumPy..."

# MUST use cython for cross-python
cd cython
pip install -v --no-binary :all: .
cd ..

# install pypi-build for cross-python
pip install -v --no-binary :all: build

#build-pip install meson-python

################################## Build NumPy ##################################

info "building NumPy"

cd numpy
rm -rf ./dist
#VENDORED_MESON=${CUR_DIR}/numpy/vendored-meson/meson/meson.py
#python ${VENDORED_MESON} setup --reconfigure --prefix=${CUR_DIR}/xdist51 --cross-file ../meson-scripts/ohos-build.meson xbuild-ohos
#cd xbuild-ohos
#python ${VENDORED_MESON} compile --verbose
#python ${VENDORED_MESON} install
#cd ..
python -m build --wheel -Csetup-args="--cross-file=${CUR_DIR}/meson-scripts/ohos-build.meson"
pip install -v ./dist/*.whl
cd ..


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

cp numpy/dist/* ${PYPKG_OUTPUT_WHEEL_DIR}
cp scipy/dist/* ${PYPKG_OUTPUT_WHEEL_DIR}


. cleanup-pypkg-env.sh


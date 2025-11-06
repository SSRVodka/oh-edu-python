#!/bin/bash
# Build onnxruntime and opencv (python packages)

. setup-pypkg-env.sh


ONNXRUNTIME_BUILD_TYPE=RelWithDebInfo
BUILD_DIRNAME=ohos-build

OUTPUT_WHEEL_DIR=${PYPKG_OUTPUT_WHEEL_DIR}
mkdir -p ${OUTPUT_WHEEL_DIR}


################################## Build Dependencies For onnxruntime pkg ##################################

# Note: wheel pkg & setuptools is required for cross-python
pip install wheel setuptools


################################## Build onnxruntime pkg ##################################

# NOTE: Native library extended
OUTPUT_DIR=${PYPKG_NATIVE_OUTPUT_DIR}.onnxruntime

pushd onnxruntime
if [[ ! -f patched ]]; then
	git apply ${CUR_DIR}/patches/oh-onnxruntime.patch
	touch patched
fi
PATH=${OHOS_SDK}/native/build-tools/cmake/bin:$PATH ./build.sh \
	--update --build \
	--config ${ONNXRUNTIME_BUILD_TYPE} \
	--build_shared_lib \
	--build_wheel \
	--parallel \
	--build_dir ${BUILD_DIRNAME} \
	--allow_running_as_root \
	--cmake_extra_defines \
   CMAKE_INSTALL_PREFIX=${OUTPUT_DIR} \
   CMAKE_INSTALL_LIBDIR=${OHOS_LIBDIR} \
   CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_CONFIG} \
   OHOS_ARCH=${ARCH} \
   CMAKE_ASM_FLAGS="-Wno-unused-command-line-argument" \
   CMAKE_C_FLAGS="${CFLAGS}" \
   CMAKE_CXX_FLAGS="${CXXFLAGS}" \
   CMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" \
   CMAKE_MODULE_LINKER_FLAGS="${LDFLAGS}" \
   CMAKE_VERBOSE_MAKEFILE=ON \
   onnxruntime_ENABLE_PYTHON=ON \
   PYTHON_INCLUDE_DIR=${TARGET_ROOT}.Python/include/python${PY_VERSION} \
   NUMPY_INCLUDE_DIR=${NUMPY_LIBROOT}/include \
   onnxruntime_CROSS_COMPILING=ON \
   onnxruntime_ENABLE_CPU_FP16_OPS=OFF \
   CPUINFO_BUILD_PKG_CONFIG=OFF \
   BUILD_TESTING=OFF \
   BUILD_GMOCK=OFF \
   protobuf_USE_EXTERNAL_GTEST=OFF \
   onnxruntime_BUILD_SHARED_LIB=ON \
   onnxruntime_ENABLE_CPUINFO=OFF \
   onnxruntime_BUILD_UNIT_TESTS=OFF

${CMAKE_BIN} --install ${BUILD_DIRNAME}/${ONNXRUNTIME_BUILD_TYPE}
popd

patch_libdir_origin "onnxruntime" "" ${OUTPUT_DIR}

# for pkg builder
if [ ! -f ${TARGET_ROOT}.onnxruntime ]; then
	ln -s ${OUTPUT_DIR} ${TARGET_ROOT}.onnxruntime
fi

################################## Build opencv & opencv pkg ##################################
# TODO: move cv2 dir to platlibdir
#OUTPUT_DIR=${PYPKG_NATIVE_OUTPUT_DIR}.opencv

# make opencv's cmake happy
mkdir -p "${TARGET_ROOT}/include"

pushd opencv-python

# use $CFLAGS in env when building a python pkg
build_cmakeproj_with_deps "opencv" "ffmpeg OpenBLAS" "\
	-DCMAKE_FIND_ROOT_PATH=${HOST_PYTHON_DIST} \
	-DPYTHON_INCLUDE_DIRS=${HOST_PYTHON_DIST}/include \
	-DPYTHON3_INCLUDE_PATH=${HOST_PYTHON_DIST}/include/python${PY_VERSION} \
	-DPYTHON3_LIBRARIES=${HOST_PYTHON_DIST}/${OHOS_LIBDIR}/libpython${PY_VERSION}.so \
	-DPYTHON3_NUMPY_INCLUDE_DIRS=${NUMPY_LIBROOT}/include" \
	"" \
	"$CFLAGS" \
	"-D__MUSL__ -D__OPENHARMONY__ -D__OHOS__" \
	"$LDFLAGS" \
	"20"


#pushd opencv
#$OHOS_SDK/native/build-tools/cmake/bin/cmake \
#	-DCMAKE_C_FLAGS="${CFLAGS}" \
#	-DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
#	-DCMAKE_TOOLCHAIN_FILE=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake \
#	-DCMAKE_FIND_ROOT_PATH=${HOST_PYTHON_DIST} \
#	-DCMAKE_INSTALL_PREFIX=${OUTPUT_DIR} \
#	-DPYTHON_INCLUDE_DIRS=${HOST_PYTHON_DIST}/include \
#	-DPYTHON3_INCLUDE_PATH=${HOST_PYTHON_DIST}/include/python${PY_VERSION} \
#	-DPYTHON3_LIBRARIES=${HOST_PYTHON_DIST}/${OHOS_LIBDIR}/libpython${PY_VERSION}.so \
#	-DPYTHON3_NUMPY_INCLUDE_DIRS=${NUMPY_LIBROOT}/include \
#	-DOHOS_ARCH=${ARCH} \
#	-B ohos-build
#cmake --build ohos-build --config Release -- -j20
#cmake --install ohos-build
#
#popd

#patchelf --add-needed libpython${PY_VERSION}.so ${OUTPUT_DIR}/lib/python${PY_VERSION}/site-packages/cv2/python-${PY_VERSION}/cv2.cpython-${PY_VERSION_CODE}-${ARCH}-linux-ohos.so
patchelf --add-needed libpython${PY_VERSION}.so ${TARGET_ROOT}.opencv/lib/python${PY_VERSION}/site-packages/cv2/python-${PY_VERSION}/cv2.cpython-${PY_VERSION_CODE}-${OHOS_CPU}-linux-ohos.so

# TODO: fix wheel build error
#pip install scikit-build
##pip wheel . --verbose
## build flags for skbuild
#_cv_deps="ffmpeg OpenBLAS"
#for _cv_dep in $_cv_deps; do
#	CFLAGS="-I${TARGET_ROOT}.${_cv_dep}/include $CFLAGS"
#	LDFLAGS="-L${TARGET_ROOT}.${_cv_dep}/${OHOS_LIBDIR} $LDFLAGS"
#	PKG_CONFIG_LIBDIR="${TARGET_ROOT}.${_cv_dep}/${OHOS_LIBDIR}/pkgconfig:${PKG_CONFIG_LIBDIR}"
#done
#CXXFLAGS="$CFLAGS"
## patch setup.py
#_cv_py_exe="${HOST_PYTHON}"
#_cv_py_numpy_include="${NUMPY_LIBROOT}/include"
#_cv_py_common_include=${HOST_PYTHON_DIST}/include
#_cv_py_include="${HOST_PYTHON_DIST}/include/python${PY_VERSION}"
#_cv_py_lib="${HOST_PYTHON_DIST}/${OHOS_LIBDIR}/libpython${PY_VERSION}.so"
#_cv_cmake_shared=ON
#sed -i -e "s|\(python_version = \).*|\1\"${PY_VERSION}\"|" \
#	-e "s|\(python_lib_path = \).*|\1\"${_cv_py_lib}\"|" \
#	-e "s|\(python_include_dir = \).*\(.replace(\)|\1\"${_cv_py_include}\"\2|" \
#	-e "s|\(\"-DPYTHON3_EXECUTABLE=\).*|\1${_cv_py_exe}\",|" \
#	-e "s|\(\"-DPYTHON_DEFAULT_EXECUTABLE=\).*|\1\",|" \
#	-e "s|\(\"-DPYTHON3_INCLUDE_DIR=\).*|\1\",\"-DPYTHON3_INCLUDE_PATHS=${_cv_py_include}\",|" \
#	-e "s|\(\"-DPYTHON3_LIBRARY=\).*|\1\",\"-DPYTHON3_LIBRARIES=${_cv_py_lib}\",|" \
#	-e "s|\(\"-DBUILD_SHARED_LIBS=\).*|\1${_cv_cmake_shared}\",\"-DCMAKE_FIND_ROOT_PATH=${HOST_PYTHON_DIST}\",\"-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_CONFIG}\",\"-DPYTHON3_NUMPY_INCLUDE_DIRS=${_cv_py_numpy_include}\",\"-DCMAKE_CROSSCOMPILING=ON\",\"-DCMAKE_VERBOSE_MAKEFILE=ON\",\"-DCMAKE_C_FLAGS=${CFLAGS}\",\"-DCMAKE_CXX_FLAGS=${CXXFLAGS}\",\"-DCMAKE_SHARED_LINKER_FLAGS=${LDFLAGS}\",|" \
#	-e "\|CMAKE_ARGS|! s|\(\"-DPYTHON3_LIMITED_API=\).*|\1OFF\",|" \
#	setup.py
#	#-e "s|\(\"-DPYTHON3_EXECUTABLE=\).*|\1${_cv_py_exe}\",|" \
#	#-e "s|\(\"-DPYTHON_DEFAULT_EXECUTABLE=\).*|\1${_cv_py_exe}\",|" \
#	#-e "s|\(\"-DPYTHON3_INCLUDE_DIR=\).*|\1${_cv_py_include}\",\"-DPYTHON3_INCLUDE_PATHS=${_cv_py_include}\",\"-DPYTHON_INCLUDE_DIRS=${_cv_py_common_include}\",|" \
#	#-e "s|\(\"-DPYTHON3_LIBRARY=\).*|\1${_cv_py_lib}\",\"-DPYTHON3_LIBRARIES=${_cv_py_lib}\",|" \
#
#PATH="${OHOS_SDK}/native/build-tools/cmake/bin:$PATH" pip install --no-binary :all: --no-build-isolation .
##PATH="${OHOS_SDK}/native/build-tools/cmake/bin:$PATH" python setup.py bdist_wheel
##PATH="${OHOS_SDK}/native/build-tools/cmake/bin:$PATH" pip wheel --verbose --no-build-isolation .

popd


################################## Retrieve Python Wheels ##################################

_PKGNAME=opencv_python-4.11.0.86
_PREP_WHEEL_INFO=${_PKGNAME}.dist-info
_WHEEL_ZIP_NAME=${_PKGNAME}-cp${PY_VERSION_CODE}-cp${PY_VERSION_CODE}-linux_${OHOS_CPU}.zip

cp -r ${TARGET_ROOT}.opencv/lib/python${PY_VERSION}/site-packages/cv2 .
./RECORD.GEN.sh cv2 ${_PREP_WHEEL_INFO} > RECORD
mv RECORD ${_PREP_WHEEL_INFO}
zip -r ${_WHEEL_ZIP_NAME} ${_PREP_WHEEL_INFO} cv2
rm -rf cv2 ${_PREP_WHEEL_INFO}/RECORD
mv ${_WHEEL_ZIP_NAME} ${OUTPUT_WHEEL_DIR}/${_PKGNAME}-cp${PY_VERSION_CODE}-cp${PY_VERSION_CODE}-linux_${OHOS_CPU}.whl

cp onnxruntime/${BUILD_DIRNAME}/${ONNXRUNTIME_BUILD_TYPE}/dist/* ${OUTPUT_WHEEL_DIR}


. cleanup-pypkg-env.sh

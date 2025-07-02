#!/bin/bash
# Build onnxruntime and opencv (python packages)

. setup-pypkg-env.sh


ONNXRUNTIME_BUILD_TYPE=RelWithDebInfo
BUILD_DIRNAME=ohos-build

# NOTE: Native library extended
OUTPUT_DIR=${PYPKG_NATIVE_OUTPUT_DIR}
OUTPUT_WHEEL_DIR=${PYPKG_OUTPUT_WHEEL_DIR}
mkdir -p ${OUTPUT_WHEEL_DIR}

# override flags in setup.sh
CFLAGS="-Wno-unused-command-line-argument -fPIC -D__MUSL__=1 -D__OPENHARMONY__=1 -I${TARGET_ROOT}/include -I${TARGET_ROOT}/include/python${PY_VERSION} -I${TARGET_ROOT}/include/lzma -I${TARGET_ROOT}/include/ncursesw -I${TARGET_ROOT}/include/readline -I${TARGET_ROOT}/ssl/include -I${NUMPY_LIBROOT}/include"
CXXFLAGS="-Wno-shorten-64-to-32 $CFLAGS"
LDFLAGS="-lpython${PY_VERSION} -L${HOST_SYSROOT}/usr/lib/${ARCH}-linux-ohos -L${TARGET_ROOT}/lib -L${TARGET_ROOT}/ssl/lib64 -L${NUMPY_LIBROOT}/lib"


################################## Build Dependencies For onnxruntime pkg ##################################

# Note: wheel pkg is required for cross-python
pip install wheel


################################## Build onnxruntime pkg ##################################

cd onnxruntime
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
	--cmake_extra_defines \
   CMAKE_INSTALL_PREFIX=${OUTPUT_DIR} \
   CMAKE_TOOLCHAIN_FILE=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake \
   OHOS_ARCH=${ARCH} \
   CMAKE_ASM_FLAGS="-Wno-unused-command-line-argument" \
   CMAKE_C_FLAGS="${CFLAGS}" \
   CMAKE_CXX_FLAGS="${CXXFLAGS}" \
   CMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" \
   CMAKE_MODULE_LINKER_FLAGS="${LDFLAGS}" \
   CMAKE_VERBOSE_MAKEFILE=ON \
   onnxruntime_ENABLE_PYTHON=ON \
   PYTHON_INCLUDE_DIR=${TARGET_ROOT}/include/python${PY_VERSION} \
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

cmake --install ${BUILD_DIRNAME}/${ONNXRUNTIME_BUILD_TYPE}
cd ..

################################## Build opencv & opencv pkg ##################################

pushd opencv-python

pushd opencv
$OHOS_SDK/native/build-tools/cmake/bin/cmake \
	-DCMAKE_C_FLAGS="${CFLAGS}" \
	-DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
	-DCMAKE_TOOLCHAIN_FILE=${OHOS_SDK}/native/build/cmake/ohos.toolchain.cmake \
	-DCMAKE_FIND_ROOT_PATH=${HOST_PYTHON_DIST} \
	-DCMAKE_INSTALL_PREFIX=${OUTPUT_DIR} \
	-DPYTHON_INCLUDE_DIRS=${HOST_PYTHON_DIST}/include \
	-DPYTHON3_INCLUDE_PATH=${HOST_PYTHON_DIST}/include/python${PY_VERSION} \
	-DPYTHON3_LIBRARIES=${HOST_PYTHON_DIST}/lib/libpython${PY_VERSION}.so \
	-DPYTHON3_NUMPY_INCLUDE_DIRS=${NUMPY_LIBROOT}/include \
	-DOHOS_ARCH=${ARCH} \
	-B ohos-build
cmake --build ohos-build --config Release -- -j20
cmake --install ohos-build

patchelf --add-needed libpython${PY_VERSION}.so ${OUTPUT_DIR}/lib/python${PY_VERSION}/site-packages/cv2/python-${PY_VERSION}/cv2.cpython-${PY_VERSION_CODE}-${ARCH}-linux-ohos.so

popd

pip install scikit-build
# pip wheel . --verbose
python setup.py bdist_wheel

popd

################################## Retrieve Python Wheels ##################################

# _PKGNAME=opencv_python-4.11.0.86
# _PREP_WHEEL_INFO=${_PKGNAME}.dist-info
# _WHEEL_ZIP_NAME=${_PKGNAME}-cp${PY_VERSION_CODE}-cp${PY_VERSION_CODE}-linux_${ARCH}.zip

# cp -r ${OUTPUT_DIR}/lib/python${PY_VERSION}/site-packages/cv2 .
# ./RECORD.GEN.sh cv2 ${_PREP_WHEEL_INFO} > RECORD
# mv RECORD ${_PREP_WHEEL_INFO}
# zip -r ${_WHEEL_ZIP_NAME} ${_PREP_WHEEL_INFO} cv2
# rm -rf cv2
# mv ${_WHEEL_ZIP_NAME} ${OUTPUT_WHEEL_DIR}/${_PKGNAME}-cp${PY_VERSION_CODE}-cp${PY_VERSION_CODE}-linux_${ARCH}.whl

cp onnxruntime/${BUILD_DIRNAME}/${ONNXRUNTIME_BUILD_TYPE}/dist/* ${OUTPUT_WHEEL_DIR}
cp opencv-python/dist/* ${OUTPUT_WHEEL_DIR}


. cleanup-pypkg-env.sh

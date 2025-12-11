#!/bin/bash
# Note: it must be called after build-pypkg-numpy-and-scipy.sh is executed (cython dep)

set -e

cd $(dirname $(readlink -f $0))

# first build on host machine (for gRPC CPP plugin)

cmake -DCMAKE_VERBOSE_MAKEFILE=ON \
	-DgRPC_BUILD_TESTS=OFF \
	-DCMAKE_CXX_STANDARD=17 \
	-B grpc/host-build -S grpc
cmake --build grpc/host-build --config Release -- -j20
_grpc_plugin_bin_dir=$PWD/grpc/host-build
_protoc_bin_dir=$PWD/grpc/host-build/third_party/protobuf
ls -lah $_grpc_plugin_bin_dir/grpc_cpp_plugin
ls -lah $_protoc_bin_dir/protoc

. setup-pypkg-env.sh

# set grpc plugin dir (host build) for cross-make to use
_pre_grpc_PATH=$PATH
PATH="$PATH:$_grpc_plugin_bin_dir:$_protoc_bin_dir"

# use CC without --target to make grpc build tools happy
CC="${OHOS_SDK}/native/llvm/bin/clang"
CXX="${OHOS_SDK}/native/llvm/bin/clang++"
CFLAGS="--target=${OHOS_CPU}-linux-ohos ${CFLAGS}"
CXXFLAGS=${CFLAGS}
LDFLAGS="--target=${OHOS_CPU}-linux-ohos ${LDFLAGS}"


pushd grpc
git submodule update --init
pip install -v --no-binary :all: -r requirements.txt
if [[ ! -f patched ]]; then
	git apply ${CUR_DIR}/patches/oh-grpc.patch
	touch patched
fi
# Note: patch setup.py to avoid using /usr/include/ssl (host machine headers)
# sed -i '/^#/!s/^\(.*SSL_INCLUDE = (os.path.join("\(\/usr\)", "include", "openssl"),\).*$/#\1/' setup.py
GRPC_PYTHON_BUILD_WITH_CYTHON=1 GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_BUILD_WITH_BORING_SSL_ASM=0 pip install -v --no-binary :all: .
patchelf --add-needed libpython${PY_VERSION}.so pyb/lib.linux-${OHOS_CPU}-cpython-${PY_VERSION_CODE}/grpc/_cython/cygrpc.cpython-${PY_VERSION_CODE}-${OHOS_CPU}-linux-ohos.so
GRPC_PYTHON_BUILD_WITH_CYTHON=1 GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_BUILD_WITH_BORING_SSL_ASM=0 python3 setup.py bdist_wheel
pushd tools/distrib/python/grpcio_tools
python ../make_grpcio_tools.py
GRPC_PYTHON_BUILD_WITH_CYTHON=1 GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_BUILD_WITH_BORING_SSL_ASM=0 pip install -v --no-binary :all: .
patchelf --add-needed libpython${PY_VERSION}.so build/lib.linux-${OHOS_CPU}-cpython-${PY_VERSION_CODE}/grpc_tools/_protoc_compiler.cpython-${PY_VERSION_CODE}-${OHOS_CPU}-linux-ohos.so
GRPC_PYTHON_BUILD_WITH_CYTHON=1 GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_BUILD_WITH_BORING_SSL_ASM=0 python3 setup.py bdist_wheel
popd
cp tools/distrib/python/grpcio_tools/dist/*.whl dist
popd

cp grpc/dist/* ${PYPKG_OUTPUT_WHEEL_DIR}

# build as system library

build_cmakeproj_with_deps "grpc" "zlib openssl" "\
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	-DgRPC_SSL_PROVIDER=package \
	-DgRPC_INSTALL=ON \
	-DgRPC_INSTALL_LIBDIR=${OHOS_LIBDIR} \
	-DgRPC_INSTALL_CMAKEDIR=${OHOS_LIBDIR}/cmake/grpc \
	-DgRPC_ZLIB_PROVIDER=package \
	-DCMAKE_CXX_STANDARD=17 \
	-DABSL_PROPAGATE_CXX_STD=ON \
	" \
	"" \
	"" \
	"" \
	"" \
	"20"

## remove unnecessary libs in arch-independent path
#rm -rf ${TARGET_ROOT}.grpc/lib/{cmake,pkgconfig,*.a}

export PATH=$_pre_grpc_PATH

. cleanup-pypkg-env.sh


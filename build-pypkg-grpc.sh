#!/bin/bash

_GRPC_BACKUP_CC=${CC}
_GRPC_BACKUP_CXX=${CXX}
_GRPC_BACKUP_CFLAGS=${CFLAGS}
_GRPC_BACKUP_CXXFLAGS=${CXXFLAGS}
_GRPC_BACKUP_LDFLAGS=${LDFLAGS}

. setup-pypkg-env.sh

# override flags in setup.sh
export CC="${OHOS_SDK}/native/llvm/bin/clang"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++"
export CFLAGS="--target=${OHOS_CPU}-linux-ohos ${CFLAGS}"
export CXXFLAGS=${CFLAGS}
export LDFLAGS="--target=${OHOS_CPU}-linux-ohos ${LDFLAGS}"

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
patchelf --add-needed libpython${PY_VERSION}.so pyb/lib.linux-${ARCH}-cpython-${PY_VERSION_CODE}/grpc/_cython/cygrpc.cpython-${PY_VERSION_CODE}-${ARCH}-linux-ohos.so
GRPC_PYTHON_BUILD_WITH_CYTHON=1 GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_BUILD_WITH_BORING_SSL_ASM=0 python3 setup.py bdist_wheel
pushd tools/distrib/python/grpcio_tools
python ../make_grpcio_tools.py
GRPC_PYTHON_BUILD_WITH_CYTHON=1 GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_BUILD_WITH_BORING_SSL_ASM=0 pip install -v --no-binary :all: .
patchelf --add-needed libpython${PY_VERSION}.so build/lib.linux-${ARCH}-cpython-${PY_VERSION_CODE}/grpc_tools/_protoc_compiler.cpython-${PY_VERSION_CODE}-${ARCH}-linux-ohos.so
GRPC_PYTHON_BUILD_WITH_CYTHON=1 GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_BUILD_WITH_BORING_SSL_ASM=0 python3 setup.py bdist_wheel
popd
cp tools/distrib/python/grpcio_tools/dist/*.whl dist
popd

cp grpc/dist/* ${PYPKG_OUTPUT_WHEEL_DIR}

. cleanup-pypkg-env.sh

export CC=${_GRPC_BACKUP_CC}
export CXX=${_GRPC_BACKUP_CXX}
export CFLAGS=${_GRPC_BACKUP_CFLAGS}
export CXXFLAGS=${_GRPC_BACKUP_CXXFLAGS}
export LDFLAGS=${_GRPC_BACKUP_LDFLAGS}

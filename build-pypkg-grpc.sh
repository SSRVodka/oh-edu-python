#!/bin/bash

. setup-pypkg-env.sh

cd grpc
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
cd tools/distrib/python/grpcio_tools
python ../make_grpcio_tools.py
GRPC_PYTHON_BUILD_WITH_CYTHON=1 GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_BUILD_WITH_BORING_SSL_ASM=0 pip install -v --no-binary :all: .
patchelf --add-needed libpython${PY_VERSION}.so build/lib.linux-${ARCH}-cpython-${PY_VERSION_CODE}/grpc_tools/_protoc_compiler.cpython-${PY_VERSION_CODE}-${ARCH}-linux-ohos.so
GRPC_PYTHON_BUILD_WITH_CYTHON=1 GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_BUILD_WITH_BORING_SSL_ASM=0 python3 setup.py bdist_wheel
cd ..
cp tools/distrib/python/grpcio_tools/dist/grpcio_tools-1.73.0-cp${PY_VERSION_CODE}-cp${PY_VERSION_CODE}-linux_${ARCH}.whl dist
cd ..

. cleanup-pypkg-env.sh

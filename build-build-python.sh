#!/bin/bash
set -Eeuo pipefail

BUILD_PYTHON_DIST="$1"
echo "[INFO] Set Build-Python Destination: $1"

# Build build python first
cd BPython

./configure \
	--prefix=${BUILD_PYTHON_DIST} \
	--enable-shared
make -j
make install
cd ..

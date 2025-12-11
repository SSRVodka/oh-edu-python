#!/bin/bash

set -Eeuo pipefail

#./download-python.sh
#./build-python.sh
#./build-openblas.sh
#./build-ffmpeg.sh
#./download-python.sh --rm
#./download-gcc.sh
#./build-gcc.sh
#./download-gcc.sh --rm
#./download-pypkgs.sh
#./build-pypkg-numpy-scipy.sh
#./build-pypkg-onnx-opencv.sh
#./download-pypkgs.sh --rm
#
#./download-pypkg-grpc.sh
#./build-pypkg-grpc.sh
#rm -rf grpc
#
#./download-misc.sh
#./build-misc.sh
#./download-misc.sh --rm
#
#./download-llvm.sh
#./build-llvm.sh
#rm -rf musl llvm/ohos-build
#
#./download-gui.sh
#./build-gui.sh
#./build-pypkg-bullet.sh
#./download-gui.sh --rm
#
./download-qt5.sh
./build-qt5.sh
rm -rf qt5-ohos qt-ohos-patches


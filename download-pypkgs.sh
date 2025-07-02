#!/bin/bash
set -Eeuo pipefail

CACHE_FILE=__hw_cache2.tar.gz
DIRS="cython numpy scipy onnxruntime opencv grpc"

rm -rf $DIRS

wget_source() {
    wget -O tmp $1
    if [[ $1 == *.zip ]]; then
        unzip tmp
    elif [[ $1 == *.tar.gz ]]; then
        tar -zxpvf tmp
    elif [[ $1 == *.tgz ]]; then
        tar -xpvf tmp
    else
        echo "Unsupported file format: $1"
        exit 1
    fi
    rm tmp
}

if [ -f ${CACHE_FILE} ]; then

tar -zxpvf ${CACHE_FILE}

else

wget_source https://github.com/cython/cython/archive/refs/tags/3.0.12.zip
mv cython-3.0.12 cython

git clone https://github.com/numpy/numpy.git
pushd numpy
# choose numpy version (DETACH)
# NOTE: you also need to change setup-pypkg-env.sh if you change this
git checkout v2.3.1
# git checkout v1.26.5
git submodule update --init --recursive
popd
git clone https://github.com/scipy/scipy.git
pushd scipy
git checkout v1.15.3
git submodule sync && git submodule update --init --recursive
popd


git clone https://github.com/microsoft/onnxruntime
pushd onnxruntime
git checkout v1.18.2
popd

wget_source https://github.com/opencv/opencv/archive/refs/tags/4.11.0.zip
mv opencv-4.11.0 opencv

git clone -b v1.73.0 https://github.com/grpc/grpc
pushd grpc
git submodule update --init
popd


# wget_source https://codeload.github.com/Geekgineer/YOLOs-CPP/zip/refs/heads/main
# mv YOLOs-CPP-main YOLOs-CPP


# git clone https://github.com/pytorch/pytorch --recursive

tar -zcpvf $CACHE_FILE $DIRS

fi

#!/bin/bash
set -Eeuo pipefail

CACHE_FILE=__hw_cache2.tar.gz
DIRS="cython numpy scipy onnxruntime opencv"

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
git clone https://github.com/scipy/scipy.git
cd scipy
git submodule sync && git submodule update --init --recursive
cd ..


wget_source https://github.com/microsoft/onnxruntime/archive/refs/tags/v1.18.2.tar.gz
mv onnxruntime-1.18.2 onnxruntime

wget_source https://github.com/opencv/opencv/archive/refs/tags/4.11.0.zip
mv opencv-4.11.0 opencv

# wget_source https://codeload.github.com/Geekgineer/YOLOs-CPP/zip/refs/heads/main
# mv YOLOs-CPP-main YOLOs-CPP


# git clone https://github.com/pytorch/pytorch --recursive

tar -zcpvf $CACHE_FILE $DIRS

fi

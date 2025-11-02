#!/bin/bash
set -Eeuo pipefail

. setup.sh

CACHE_FILE=__hw_cache_pypkgs.tar.gz
#DIRS="cython numpy numpy2 scipy onnxruntime opencv opencv-python grpc"
DIRS="cython numpy numpy2 onnxruntime opencv-python"

rm -rf $DIRS

if [ -f ${CACHE_FILE} ]; then

tar -zxpvf ${CACHE_FILE}

else

wget_source https://github.com/cython/cython/archive/refs/tags/3.0.12.zip
mv cython-3.0.12 cython

# NOTE: you also need to change setup-pypkg-env.sh if you change numpy version
git clone https://github.com/numpy/numpy.git numpy2
pushd numpy2
git checkout v2.3.1
git submodule update --init --recursive
popd
git clone https://github.com/numpy/numpy.git numpy
pushd numpy
git checkout v1.26.5
git submodule update --init --recursive
popd

#git clone https://github.com/scipy/scipy.git
#pushd scipy
#git checkout v1.15.3
#git submodule sync && git submodule update --init --recursive
#popd


git clone https://github.com/microsoft/onnxruntime
pushd onnxruntime
git checkout v1.18.2
popd

#wget_source https://github.com/opencv/opencv/archive/refs/tags/4.11.0.zip
#mv opencv-4.11.0 opencv

git clone https://github.com/opencv/opencv-python.git
pushd opencv-python
git switch 4.x
git submodule sync && git submodule update --init --recursive
popd

# wget_source https://codeload.github.com/Geekgineer/YOLOs-CPP/zip/refs/heads/main
# mv YOLOs-CPP-main YOLOs-CPP


# git clone https://github.com/pytorch/pytorch --recursive

# force download from Internet
#tar -zcpvf $CACHE_FILE $DIRS

fi

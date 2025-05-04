#!/bin/bash

wget https://github.com/cython/cython/archive/refs/tags/3.0.12.zip
unzip 3.0.12.zip
mv cython-3.0.12 cython

git clone https://github.com/numpy/numpy.git
git clone https://github.com/scipy/scipy.git
cd scipy
git submodule sync && git submodule update --init --recursive
cd ..


#!/bin/bash

set -Eeuo pipefail

CACHE_FILE=__hw_cache_gcc.tar.gz

SRCS="gmp mpfr mpc gcc binutils m4 patchelf"

rm -rf $SRCS

wget_source() {
    wget -O tmps $1
    if [[ $1 == *.zip ]]; then
        unzip tmps
    elif [[ $1 == *.tar.gz ]]; then
        tar -zxpvf tmps
    elif [[ $1 == *.tgz ]]; then
        tar -xpvf tmps
    elif [[ $1 == *.tar.xz ]]; then
	tar -Jxpvf tmps
    else
        echo "Unsupported file format: $1"
        exit 1
    fi
    rm tmps
}

if [ -f "$CACHE_FILE" ]; then
	
tar -zxpvf ${CACHE_FILE}

else

wget_source https://mirrors.tuna.tsinghua.edu.cn/gnu/gmp/gmp-6.3.0.tar.xz
mv gmp-6.3.0 gmp

wget_source https://mirrors.tuna.tsinghua.edu.cn/gnu/mpfr/mpfr-4.2.2.zip
mv mpfr-4.2.2 mpfr

wget_source https://mirrors.tuna.tsinghua.edu.cn/gnu/mpc/mpc-1.3.1.tar.gz
mv mpc-1.3.1 mpc

wget_source https://mirrors.tuna.tsinghua.edu.cn/gnu/gcc/gcc-15.2.0/gcc-15.2.0.tar.xz
mv gcc-15.2.0 gcc

wget_source https://mirrors.tuna.tsinghua.edu.cn/gnu/binutils/binutils-2.44.tar.xz
mv binutils-2.44 binutils

wget_source https://mirrors.tuna.tsinghua.edu.cn/gnu/m4/m4-1.4.19.tar.xz
mv m4-1.4.19 m4

wget_source https://github.com/NixOS/patchelf/archive/refs/tags/0.18.0.zip
mv patchelf-0.18.0 patchelf

tar -zcpvf ${CACHE_FILE} $SRCS

fi


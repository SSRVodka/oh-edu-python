#!/bin/bash

set -Eeuo pipefail

CACHE_FILE=__hw_cache.tar.gz
DIRS="zlib libffi bzip2 xz readline openssl sqlite ncurses gettext Python BPython OpenBLAS libaacplus x264 alsa-lib ffmpeg"

rm -rf $DIRS

wget_source() {
    wget -O tmp $1
    if [[ $1 == *.zip ]]; then
        unzip tmp
    elif [[ $1 == *.tar.gz ]]; then
        tar -zxpvf tmp
    elif [[ $1 == *.bz2 ]]; then
        tar -xpvf tmp
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

wget_source https://github.com/madler/zlib/archive/refs/tags/v1.3.1.zip
mv zlib-1.3.1 zlib

wget_source https://github.com/libffi/libffi/archive/refs/tags/v3.4.8.zip
mv libffi-3.4.8 libffi

wget_source https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
mv bzip2-1.0.8 bzip2

wget_source https://github.com/tukaani-project/xz/archive/refs/tags/v5.8.1.zip
mv xz-5.8.1 xz

wget_source https://ftp.gnu.org/gnu/readline/readline-8.2.tar.gz
mv readline-8.2 readline

wget_source https://github.com/openssl/openssl/archive/refs/tags/openssl-3.5.0.zip
mv openssl-openssl-3.5.0 openssl

wget_source https://www.sqlite.org/2025/sqlite-autoconf-3490100.tar.gz
mv sqlite-autoconf-3490100 sqlite

wget_source https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.5.tar.gz
mv ncurses-6.5 ncurses

wget_source https://ftp.gnu.org/pub/gnu/gettext/gettext-0.24.tar.gz
mv gettext-0.24 gettext

wget_source https://www.python.org/ftp/python/3.11.4/Python-3.11.4.tgz
mv Python-3.11.4 Python
cp -r Python BPython

wget_source https://github.com/OpenMathLib/OpenBLAS/archive/refs/tags/v0.3.29.zip
mv OpenBLAS-0.3.29 OpenBLAS

wget_source http://tipok.org.ua/downloads/media/aacplus/libaacplus/libaacplus-2.0.2.tar.gz
mv libaacplus-2.0.2 libaacplus

wget_source https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2
mv x264-master x264

wget_source http://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.14.tar.bz2
mv alsa-lib-1.2.14 alsa-lib

wget_source https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n4.3.9.zip
mv FFmpeg-n4.3.9 ffmpeg

tar -zcpvf $CACHE_FILE $DIRS

fi

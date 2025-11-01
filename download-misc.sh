#!/bin/bash

set -Eeuo pipefail

. setup.sh


CACHE_FILE=__hw_cache_misc.tar.gz

SRCS="acl attr assimp fmt yaml-cpp libpsl curl boost eigen qhull libccd SuiteSparse gflags glog ceres-solver zstd zeromq libexpat libpng freetype g2o geographiclib tinyxml2 oneTBB pcre2 swig YDLidar-SDK llama.cpp flann pcl libdrm"

rm -rf $SRCS

if [ -f "$CACHE_FILE" ]; then
	
tar -zxpvf ${CACHE_FILE}

else

#wget_source https://download.savannah.nongnu.org/releases/acl/acl-2.3.1.tar.xz
#mv acl-2.3.1 acl
#
#wget_source http://download.savannah.gnu.org/releases/attr/attr-2.5.1.tar.xz
#mv attr-2.5.1 attr
#
#wget_source https://github.com/assimp/assimp/archive/refs/tags/v6.0.2.zip
#mv assimp-6.0.2 assimp
#
#wget_source https://github.com/fmtlib/fmt/archive/refs/tags/12.1.0.zip
#mv fmt-12.1.0 fmt
#
#wget_source https://github.com/jbeder/yaml-cpp/archive/refs/tags/0.8.0.zip
#mv yaml-cpp-0.8.0 yaml-cpp
#
#wget_source https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz
#mv libpsl-0.21.5 libpsl
#
#wget_source https://github.com/curl/curl/archive/refs/tags/curl-8_16_0.zip
#mv curl-curl-8_16_0 curl
#
#wget_source https://archives.boost.io/release/1.81.0/source/boost_1_81_0.tar.gz
#mv boost_1_81_0 boost
#
#wget_source https://gitlab.com/libeigen/eigen/-/archive/3.4.1/eigen-3.4.1.tar.gz
#mv eigen-3.4.1 eigen
#
#wget_source https://github.com/qhull/qhull/archive/refs/tags/v8.1-alpha1.zip
#mv qhull-8.1-alpha1 qhull
#
#wget_source https://github.com/danfis/libccd/archive/refs/tags/v2.1.zip
#mv libccd-2.1 libccd
#
#wget_source https://github.com/DrTimothyAldenDavis/SuiteSparse/archive/refs/tags/v7.11.0.zip
#mv SuiteSparse-7.11.0 SuiteSparse
#
#wget_source https://github.com/gflags/gflags/archive/refs/tags/v2.2.2.zip
#mv gflags-2.2.2 gflags
#
#wget_source https://github.com/google/glog/archive/refs/tags/v0.7.1.zip
#mv glog-0.7.1 glog
#
#wget_source https://github.com/ceres-solver/ceres-solver/archive/refs/tags/2.2.0.zip
#mv ceres-solver-2.2.0 ceres-solver

wget_source https://github.com/facebook/zstd/archive/refs/tags/v1.5.7.zip
mv zstd-1.5.7 zstd

wget_source https://github.com/zeromq/libzmq/releases/download/v4.3.5/zeromq-4.3.5.tar.gz
mv zeromq-4.3.5 zeromq

wget_source https://github.com/libexpat/libexpat/archive/refs/tags/R_2_7_3.zip
mv libexpat-R_2_7_3 libexpat

wget_source https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.50.zip
mv libpng-1.6.50 libpng

wget_source https://downloads.sourceforge.net/freetype/freetype-2.14.1.tar.xz
mv freetype-2.14.1 freetype

wget_source https://github.com/RainerKuemmerle/g2o/archive/refs/tags/20241228_git.zip
mv g2o-20241228_git g2o

wget_source https://github.com/geographiclib/geographiclib/archive/refs/tags/v2.6.zip
mv geographiclib-2.6 geographiclib

wget_source https://github.com/leethomason/tinyxml2/archive/refs/tags/11.0.0.zip
mv tinyxml2-11.0.0 tinyxml2

wget_source https://github.com/uxlfoundation/oneTBB/archive/refs/tags/v2022.3.0.zip
mv oneTBB-2022.3.0 oneTBB

wget_source https://github.com/PCRE2Project/pcre2/archive/refs/tags/pcre2-10.47.zip
mv pcre2-pcre2-10.47 pcre2

wget_source https://github.com/swig/swig/archive/refs/tags/v4.4.0.zip
mv swig-4.4.0 swig

wget_source https://github.com/YDLIDAR/YDLidar-SDK/archive/refs/tags/V1.2.7.zip
mv YDLidar-SDK-1.2.7 YDLidar-SDK

wget_source https://github.com/ggml-org/llama.cpp/archive/refs/tags/b6910.zip
mv llama.cpp-b6910 llama.cpp

wget_source https://github.com/flann-lib/flann/archive/refs/tags/1.9.2.zip
mv flann-1.9.2 flann

wget_source https://github.com/PointCloudLibrary/pcl/releases/download/pcl-1.15.1/source.tar.gz
# pcl don't need to mv

wget_source https://dri.freedesktop.org/libdrm/libdrm-2.4.127.tar.xz
mv libdrm-2.4.127 libdrm

#tar -zcpvf ${CACHE_FILE} $SRCS

fi


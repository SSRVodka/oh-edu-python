#!/bin/bash
set -Eeuo pipefail

. setup.sh

rm -rf grpc

git clone -b v1.73.0 https://github.com/grpc/grpc
pushd grpc
git submodule update --init
popd


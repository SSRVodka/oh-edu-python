#!/bin/bash
set -Eeuo pipefail

. setup.sh

rm -rf grpc
if [ "${1:-}" == "--rm" ]; then
	exit 0
fi

git clone -b v1.73.0 https://github.com/grpc/grpc
pushd grpc
git submodule update --init
popd


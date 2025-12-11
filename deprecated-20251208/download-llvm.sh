#!/bin/bash

set -Eeuo pipefail

. setup.sh

wget_source https://musl.libc.org/releases/musl-1.2.5.tar.gz
mv musl-1.2.5 musl

wget_source https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-21.1.4.zip
mv llvm-project-llvmorg-21.1.4 llvm


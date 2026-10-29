#!/bin/sh
# Build the c2dmp-hsm shared library used by lua/matching/c2dmp.lua (needs libutils installed)
set -eu
cd "$(dirname "$0")"
clang++ -std=c++20 -O2 -shared -fPIC c2dmp.cpp -o libc2dmp_nvim.so

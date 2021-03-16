#!/bin/bash

mkdir _build_debug_san
cd _build_debug_san
cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined" ..
cmake --build .
cd ..

mkdir _build_rwdi_san
cd _build_rwdi_san
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined" ..
cmake --build .
cd ..

mkdir _build_release
cd _build_release
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build .
cd ..

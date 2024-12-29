#!/bin/sh

set -xe

rm -rf ./build
mkdir ./build
odin build . -out:./build/frog-buster
cp -r ./sprites ./build/sprites

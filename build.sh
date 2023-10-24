#!/bin/sh

#export GM_VERSION=1.3.31
#docker build --build-arg GM_VERSION -t gm-lambda-layer .

docker build -t gm-lambda-layer .
docker run --rm gm-lambda-layer cat /tmp/gm-1.3.31.zip > ./graphicsmagick.zip

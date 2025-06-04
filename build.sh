#!/bin/sh

#export GM_VERSION=1.3.31
#docker build --build-arg GM_VERSION -t gm-lambda-layer .
#docker run --rm - it gm-lambda-layer cat 
#docker run --rm -it --name gs-container gs100501-layer /bin/bash

docker build -t gm-lambda-layer .   #dockerfile >> Dockerfile
docker run --rm gm-lambda-layer cat /tmp/gm-1.3.31.zip > ./graphicsmagick.zip


docker build -t gs100501-layer .    #dockile >> Dockerfile_gs
docker run --rm gs100501-layer cat /tmp/gm-1.3.31.zip > ./graphicsmagick.zip

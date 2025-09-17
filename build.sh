#!/bin/sh

#export GM_VERSION=1.3.31
#docker build --build-arg GM_VERSION -t gm-lambda-layer .
#docker run --rm -it --name gm-container gm-lambda-layer /bin/bash 
#docker run --rm -it --name gs-container gs100501-layer /bin/bash
#ln -s /lib64/libexpat.so.1.6.0 /usr/lib64/libexpat.so.1 && \
docker build -t gm-lambda-layer .   #dockerfile >> Dockerfile
docker run --rm gm-lambda-layer3 cat /tmp/gm-1.3.31.zip > ./gm_v3-1.3.31.zip


docker build -t gs100501-layer .    #dockile >> Dockerfile_gs
docker run --rm gs100501-layer cat /var/task/ghostscript_v2-10.05.1.zip > ./ghostscript_v2-10.05.1.zip

#docker cp gs-container:/root/gs_v2-10.05.1.zip $windows_folder\$zip_file

FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS builder

ARG GM_VERSION=1.3.46
ARG GS_VERSION=10.07.0

ENV PREFIX=/opt/layer \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:/usr/lib64/pkgconfig \
    LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:/lib64:/usr/lib64

RUN dnf update -y && dnf install -y \
    gcc gcc-c++ make cmake autoconf automake libtool \
    tar gzip xz bzip2 bzip2-devel zip unzip patch which file findutils \
    wget git pkgconf-pkg-config \
    glibc-devel glib2-devel \
    zlib zlib-devel \
    libjpeg-turbo libjpeg-turbo-devel \
    libpng libpng-devel \
    libtiff libtiff-devel \
    libwebp libwebp-devel \
    freetype freetype-devel \
    fontconfig fontconfig-devel \
    expat expat-devel \
    lcms2 lcms2-devel \
    libxml2 libxml2-devel \
    perl \
    ca-certificates \
    ghostscript-tools-fonts \
 && dnf clean all

WORKDIR /tmp/build

# Build Ghostscript
RUN curl -fL -o ghostscript.tar.xz \
    "https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10070/ghostscript-${GS_VERSION}.tar.xz" \
 && tar -xf ghostscript.tar.xz \
 && cd ghostscript-${GS_VERSION} \
 && ./configure \
      --prefix=/usr/local \
      --disable-gtk \
      --without-x \
 && make -j"$(nproc)" \
 && make install

# Build GraphicsMagick
RUN curl -fL -o GraphicsMagick.tar.xz \
    "https://downloads.sourceforge.net/project/graphicsmagick/graphicsmagick/${GM_VERSION}/GraphicsMagick-${GM_VERSION}.tar.xz" \
 && tar -xf GraphicsMagick.tar.xz \
 && cd GraphicsMagick-${GM_VERSION} \
 && ./configure \
      --prefix=/usr/local \
      --enable-shared=yes \
      --enable-static=no \
      --with-gs-font-dir=/usr/share/fonts/default/Type1 \
      --with-quantum-depth=16 \
 && make -j"$(nproc)" \
 && make install

# Build Lambda layer structure
RUN mkdir -p \
    ${PREFIX}/bin \
    ${PREFIX}/lib \
    ${PREFIX}/etc/fonts \
    ${PREFIX}/share/fonts

# Copy binaries
RUN cp -av /usr/local/bin/gm ${PREFIX}/bin/ \
 && cp -av /usr/local/bin/gs ${PREFIX}/bin/

# Copy direct shared libraries from local installs, preserving symlinks
RUN bash -lc 'for d in /usr/local/lib /usr/local/lib64; do \
      [ -d "$d" ] || continue; \
      find "$d" -maxdepth 1 \( -type f -o -type l \) -name "*.so*" -exec cp -a {} ${PREFIX}/lib/ \; ; \
    done' || true

# Copy runtime dependencies for gm and gs, preserving symlinks and real files
RUN bash -lc 'for bin in /usr/local/bin/gm /usr/local/bin/gs; do \
      ldd "$bin" | awk "{print \$3}" | grep "^/" | sort -u | while read -r lib; do \
        cp -a --parents "$lib" /tmp/deps; \
        real="$(readlink -f "$lib" || true)"; \
        [ -n "$real" ] && [ -f "$real" ] && cp -a --parents "$real" /tmp/deps || true; \
      done; \
    done' \
 && find /tmp/deps \( -type f -o -type l \) -name '*.so*' -exec cp -a {} ${PREFIX}/lib/ \; || true

# Copy common system libs Ghostscript/GM often need in Lambda, preserving symlinks
RUN bash -lc 'for p in /lib64 /usr/lib64; do \
      [ -d "$p" ] || continue; \
      find "$p" -maxdepth 1 \( -type f -o -type l \) \( \
        -name "libexpat.so*" -o \
        -name "libfontconfig.so*" -o \
        -name "libfreetype.so*" -o \
        -name "libjpeg.so*" -o \
        -name "libpng*.so*" -o \
        -name "libtiff.so*" -o \
        -name "libwebp.so*" -o \
        -name "libz.so*" -o \
        -name "liblcms2.so*" -o \
        -name "libxml2.so*" \
      \) -exec cp -a {} ${PREFIX}/lib/ \; ; \
    done'

# Recreate critical SONAME symlinks explicitly
RUN bash -lc 'cd ${PREFIX}/lib && \
    [ -f libGraphicsMagick.so.3.26.0 ] && ln -sf libGraphicsMagick.so.3.26.0 libGraphicsMagick.so.3 || true && \
    [ -e libGraphicsMagick.so.3 ] && ln -sf libGraphicsMagick.so.3 libGraphicsMagick.so || true && \
    [ -f libGraphicsMagick++.so.12.8.2 ] && ln -sf libGraphicsMagick++.so.12.8.2 libGraphicsMagick++.so.12 || true && \
    [ -e libGraphicsMagick++.so.12 ] && ln -sf libGraphicsMagick++.so.12 libGraphicsMagick++.so || true && \
    [ -f libGraphicsMagickWand.so.2.10.2 ] && ln -sf libGraphicsMagickWand.so.2.10.2 libGraphicsMagickWand.so.2 || true && \
    [ -e libGraphicsMagickWand.so.2 ] && ln -sf libGraphicsMagickWand.so.2 libGraphicsMagickWand.so || true'

# Fonts and fontconfig
RUN cp -avr /etc/fonts/* ${PREFIX}/etc/fonts/ || true \
 && cp -avr /usr/share/fonts/* ${PREFIX}/share/fonts/ || true

# Optional size reduction
RUN strip --strip-unneeded ${PREFIX}/bin/gm || true \
 && strip --strip-unneeded ${PREFIX}/bin/gs || true \
 && find ${PREFIX}/lib -type f -name '*.so*' -exec strip --strip-unneeded {} \; || true

# Package layer
WORKDIR ${PREFIX}
RUN zip -r9 /tmp/graphicsmagick-ghostscript-al2023-layer.zip .

FROM scratch
COPY --from=builder /tmp/graphicsmagick-ghostscript-al2023-layer.zip /graphicsmagick-ghostscript-al2023-layer.zip
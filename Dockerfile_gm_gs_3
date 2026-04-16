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
RUN cp -a /usr/local/bin/gm ${PREFIX}/bin/ \
 && cp -a /usr/local/bin/gs ${PREFIX}/bin/

# Copy fonts and fontconfig
RUN cp -a /etc/fonts/. ${PREFIX}/etc/fonts/ || true \
 && cp -a /usr/share/fonts/. ${PREFIX}/share/fonts/ || true

# Recursively collect all shared-library dependencies for gm and gs.
# This avoids manually chasing missing .so files one by one.
RUN bash -lc '\
set -euo pipefail; \
mkdir -p /tmp/depstage; \
seen_file=/tmp/seen-libs.txt; \
touch "$seen_file"; \
queue="/usr/local/bin/gm /usr/local/bin/gs"; \
resolve_and_copy() { \
  local lib="$1"; \
  [ -e "$lib" ] || return 0; \
  grep -Fxq "$lib" "$seen_file" && return 0; \
  echo "$lib" >> "$seen_file"; \
  cp -a "$lib" /tmp/depstage/ || true; \
  local real; \
  real="$(readlink -f "$lib" || true)"; \
  if [ -n "${real:-}" ] && [ -e "$real" ]; then \
    grep -Fxq "$real" "$seen_file" || echo "$real" >> "$seen_file"; \
    cp -a "$real" /tmp/depstage/ || true; \
  fi; \
  local out; \
  out="$(ldd "$lib" 2>/dev/null || true)"; \
  echo "$out" | awk '\''/=> \// {print $3} /^\// {print $1}'\'' | sort -u | while read -r dep; do \
    [ -n "$dep" ] && resolve_and_copy "$dep"; \
  done; \
}; \
for item in $queue; do \
  resolve_and_copy "$item"; \
done; \
cp -a /tmp/depstage/. ${PREFIX}/lib/ || true; \
true'

# Copy directly installed /usr/local shared libs too, including symlinks
RUN bash -lc '\
for d in /usr/local/lib /usr/local/lib64; do \
  [ -d "$d" ] || continue; \
  find "$d" -maxdepth 1 \( -type f -o -type l \) -name "*.so*" -exec cp -a {} ${PREFIX}/lib/ \; ; \
done; \
true'

# Recreate SONAME symlinks automatically for versioned shared libs
RUN bash -lc '\
set -euo pipefail; \
cd ${PREFIX}/lib; \
for f in *.so.*; do \
  [ -e "$f" ] || continue; \
  base="$(echo "$f" | sed -E "s/(\\.so\\.[0-9]+).*/\\1/")"; \
  plain="$(echo "$base" | sed -E "s/(\\.so)\\.[0-9]+$/\\1/")"; \
  if [ "$f" != "$base" ]; then \
    ln -sf "$f" "$base"; \
  fi; \
  if [ "$base" != "$plain" ]; then \
    ln -sf "$base" "$plain"; \
  fi; \
done; \
true'

# Validate before packaging
RUN bash -lc '\
echo "=== gm deps ==="; \
ldd /usr/local/bin/gm || true; \
echo "=== gs deps ==="; \
ldd /usr/local/bin/gs || true; \
echo "=== packaged GraphicsMagick/WebP libs ==="; \
ls -l ${PREFIX}/lib | egrep "GraphicsMagick|webp|jpeg|png|tiff|fontconfig|freetype|xml2|lcms|expat|z\\.so" || true; \
true'

# Optional size reduction
RUN strip --strip-unneeded ${PREFIX}/bin/gm || true \
 && strip --strip-unneeded ${PREFIX}/bin/gs || true \
 && find ${PREFIX}/lib -type f -name '*.so*' -exec strip --strip-unneeded {} \; || true

# Package layer
WORKDIR ${PREFIX}
RUN zip -r9 /tmp/graphicsmagick-ghostscript-al2023-layer.zip .

FROM scratch
COPY --from=builder /tmp/graphicsmagick-ghostscript-al2023-layer.zip /graphicsmagick-ghostscript-al2023-layer.zip
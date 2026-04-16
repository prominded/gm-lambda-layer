FROM lambci/lambda-base:build

RUN yum install -y \
    libXt \
    libX11 \
    libSM \
    libICE \
    libXext \
    fontconfig \
    freetype \
    libjpeg-turbo \
    libpng \
    libtiff \
    zlib \
    expat \
    && yum clean all

WORKDIR /tmp

RUN curl -LO https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10051/ghostscript-10.05.1.tar.gz

RUN tar -zxf ghostscript-10.05.1.tar.gz

RUN cd ghostscript-10.05.1 && \
    ./configure --without-luratech --prefix=/opt && \
    make -j"$(nproc)" && \
    make install

# Export layer structure
RUN mkdir -p export/bin export/lib export/share export/etc/fonts

# Copy gs binary
RUN cp /opt/bin/gs export/bin/

# Copy Ghostscript shared resources if present
RUN if [ -d /opt/share/ghostscript ]; then cp -a /opt/share/ghostscript export/share/; fi

# Copy fonts/config if needed
RUN if [ -d /etc/fonts ]; then cp -a /etc/fonts/. export/etc/fonts/; fi

# Copy all runtime shared libraries required by gs
RUN bash -lc ' \
set -e; \
ldd /opt/bin/gs | awk '\''/=> \// {print $3} /^\// {print $1}'\'' | sort -u | while read -r lib; do \
  [ -f "$lib" ] || continue; \
  cp -av "$lib" export/lib/; \
  real="$(readlink -f "$lib" || true)"; \
  if [ -n "$real" ] && [ -f "$real" ]; then \
    cp -av "$real" export/lib/; \
  fi; \
done \
'

# Add common X11/system libs explicitly in case ldd misses soname links
RUN bash -lc ' \
for pattern in \
  "libXt.so*" \
  "libX11.so*" \
  "libSM.so*" \
  "libICE.so*" \
  "libXext.so*" \
  "libfontconfig.so*" \
  "libfreetype.so*" \
  "libjpeg.so*" \
  "libpng*.so*" \
  "libtiff.so*" \
  "libz.so*" \
  "libexpat.so*"; do \
  find /usr/lib64 /lib64 -maxdepth 1 \( -type f -o -type l \) -name "$pattern" -exec cp -av {} export/lib/ \; 2>/dev/null || true; \
done \
'

# Recreate soname symlinks
RUN bash -lc ' \
cd export/lib; \
for f in *.so.*; do \
  [ -e "$f" ] || continue; \
  base="$(echo "$f" | sed -E "s/(\\.so\\.[0-9]+).*/\\1/")"; \
  plain="$(echo "$base" | sed -E "s/(\\.so)\\.[0-9]+$/\\1/")"; \
  if [ "$f" != "$base" ]; then ln -sf "$f" "$base"; fi; \
  if [ "$base" != "$plain" ]; then \
    if [ ! -e "$plain" ] || [ -L "$plain" ]; then ln -sf "$base" "$plain"; fi; \
  fi; \
done \
'

# Optional: check what got packaged
RUN ls -l export/bin && ls -l export/lib | egrep 'libXt|libX11|libSM|libICE|libXext|libfontconfig|libfreetype' || true

RUN cd export && zip -yr /var/task/ghostscript_v2-10.05.1.zip ./*

CMD ["/bin/bash"]
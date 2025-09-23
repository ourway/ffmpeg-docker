################################################################################
# Build Stage: Compile all dependencies and a static FFmpeg binary
################################################################################
FROM alpine:3.20 AS build

# Define the installation prefix for all our compiled libraries and for FFmpeg
ARG PREFIX=/opt/ffmpeg
ENV PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"

# Install build tools and FFmpeg's library dependencies (the -dev packages)
# autoconf, automake, and libtool are needed to build fdk-aac from source
# harfbuzz-dev, fribidi-dev, and graphite2-dev are required for static libass
RUN apk add --update --no-cache \
  build-base \
  coreutils \
  autoconf \
  automake \
  libtool \
  freetype-dev \
  gcc \
  lame-dev \
  libogg-dev \
  libass-dev \
  harfbuzz-dev \
  fribidi-dev \
  graphite2-dev \
  libvpx-dev \
  libvorbis-dev \
  libwebp-dev \
  libtheora-dev \
  opus-dev \
  openssl-dev \
  pkgconf \
  rtmpdump-dev \
  wget \
  tar \
  x264-dev \
  x265-dev \
  yasm \
  nasm \
  git \
  rav1e-dev \
  zlib-dev

# 1. Compile fdk-aac from source (to avoid using the 'edge' repository)
RUN cd /tmp && \
    git clone https://github.com/mstorsjo/fdk-aac.git && \
    cd fdk-aac && \
    ./autogen.sh && \
    ./configure --prefix="${PREFIX}" --disable-shared && \
    make -j$(nproc) && \
    make install

# 2. Get FFmpeg source
RUN cd /tmp && \
  wget https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
  tar xf ffmpeg-snapshot.tar.bz2 && \
  rm ffmpeg-snapshot.tar.bz2

# 3. Compile a fully static FFmpeg binary
RUN cd /tmp/ffmpeg && \
  export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:/usr/lib/pkgconfig" && \
  ./configure \
  --prefix="${PREFIX}" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I${PREFIX}/include" \
  --extra-ldflags="-L${PREFIX}/lib" \
  --extra-libs="-lpthread -lm" \
  --enable-gpl \
  --enable-nonfree \
  --enable-libmp3lame \
  --enable-libx264 \
  --enable-libvpx \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-libopus \
  --enable-libfdk-aac \
  --enable-libass \
  --enable-libwebp \
  --enable-librav1e \
  --enable-libfreetype \
  --enable-openssl \
  --disable-ffplay \
  --disable-doc \
  --disable-debug \
  --disable-shared \
  --enable-static && \
  make -j$(nproc) && \
  make install

################################################################################
# Final Stage: Create a minimal image with the binary
################################################################################
FROM alpine:3.20

# Copy the self-contained, static FFmpeg binary from the build stage
COPY --from=build /opt/ffmpeg/bin/ffmpeg /ffmpeg

# Set the binary as the entrypoint
ENTRYPOINT ["/ffmpeg"]

# The default command is to show the help text
CMD ["-h"]

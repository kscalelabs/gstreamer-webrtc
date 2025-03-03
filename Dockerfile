# Start from a base image with Rust and essential build tools
FROM rust:latest AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    python3-pip \
    python3-venv \
    ninja-build \
    pkg-config \
    libglib2.0-dev \
    libssl-dev \
    clang \
    libc++-dev \
    libc++abi-dev \
    yasm \
    libx264-dev \
    libx265-dev \
    libvpx-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    flex \
    bison


# Create a virtual environment for Meson and activate it
RUN python3 -m venv /opt/meson-env
ENV PATH="/opt/meson-env/bin:$PATH"
RUN pip install meson

# Install cargo-c for building Rust plugins as C libraries
RUN cargo install cargo-c

# Set GStreamer version
ENV GST_VERSION=1.24.9

# Clone GStreamer repository
RUN git clone --branch $GST_VERSION --depth 1 https://gitlab.freedesktop.org/gstreamer/gstreamer.git /gstreamer

# Build and install GStreamer core and essential plugins
WORKDIR /gstreamer

# Configure with Meson, enabling base, good, bad, ugly, and libav plugins
RUN meson setup builddir \
    -Dlibav=enabled \
    -Dbase=enabled \
    -Dgood=enabled \
    -Dbad=enabled \
    -Dugly=enabled \
    -Dintrospection=enabled \
    -Ddoc=disabled

# Compile and install GStreamer and plugins
RUN ninja -C builddir
RUN ninja -C builddir install


# Clone the gst-plugins-rs repository
#RUN git clone https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs.git /gstreamer/subprojects/gst-plugins-rs
RUN git clone --depth 1 --branch gstreamer-$GST_VERSION https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs.git /gstreamer/subprojects/gst-plugins-rs

# Switch to the gst-plugins-rs directory
WORKDIR /gstreamer/subprojects/gst-plugins-rs

# Build and install the Rust WebRTC plugin
RUN cargo cbuild -p gst-plugin-webrtc --release --prefix=/usr
RUN cargo cinstall -p gst-plugin-webrtc --release --prefix=/usr

RUN cargo cbuild -p gst-plugin-rtp --release --prefix=/usr
RUN cargo cinstall -p gst-plugin-rtp --release --prefix=/usr


FROM builder AS inspection
# Cleanup build stage
#RUN apt-get remove -y build-essential cmake git python3-pip ninja-build pkg-config && \
#    apt-get autoremove -y && \
#    apt-get clean && \
#    rm -rf /var/lib/apt/lists/* /gstreamer

# Run a basic image with just the built GStreamer and plugins
FROM debian:stable-slim

COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/lib/aarch64-linux-gnu/gstreamer-1.0 /usr/lib/aarch64-linux-gnu/gstreamer-1.0
# Dependencies for running GStreamer
RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libssl-dev \
    libx11-6 \
    libxv1 \
    libxext6 \
    libxtst6 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libssl-dev \
    libgdk-pixbuf2.0-0 \
    libvpx7 \
    liblcms2-2 \
    libopenexr-dev \
    curl \
    libwebp-dev \
    libopenjp2-7 \
    librsvg2-2 \
    python3 \
    python3-dev \
    python3-gi \
    libcairo2 \
    libcairo-gobject2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV GST_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/gstreamer-1.0

# Run a basic test (optional)
CMD ["gst-launch-1.0", "--version"]

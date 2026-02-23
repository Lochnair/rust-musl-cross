FROM alpine:3.23

# ============================================================
# Base layer — shared across ALL target images.
# Install build tools, Clang/LLD, and dev utilities.
# Everything above the first ARG is cached and shared.
# ============================================================
RUN apk add --no-cache \
    bash \
    build-base \
    cmake \
    curl \
    file \
    git \
    sudo \
    unzip \
    ca-certificates \
    python3 \
    autoconf \
    automake \
    flex \
    bison \
    clang \
    lld \
    llvm \
    llvm-dev \
    clang-dev \
    clang-static \
    llvm-static

RUN mkdir -p /home/rust/libs /home/rust/src

# Set up PATH (common to all images)
ENV PATH=/root/.cargo/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

# ============================================================
# Target-specific layers below.
# All layers after ARG are specific to each target.
# ============================================================

ARG TARGET=x86_64-unknown-linux-musl

# The Alpine architecture name used by apk (e.g. x86_64, aarch64, armv7, etc.)
ARG APK_ARCH=x86_64

# The Clang target triple (e.g. x86_64-alpine-linux-musl, aarch64-alpine-linux-musl, etc.)
ARG CLANG_TARGET=x86_64-alpine-linux-musl

# Create target sysroot using Alpine packages.
# This gives us musl-libc, headers, and common libraries for the target arch.
# Users can extend the sysroot with additional packages:
#   apk --arch $APK_ARCH --root /sysroot add <package>
RUN mkdir -p /sysroot/etc/apk && \
    echo "https://dl-cdn.alpinelinux.org/alpine/v3.23/main" > /sysroot/etc/apk/repositories && \
    echo "https://dl-cdn.alpinelinux.org/alpine/v3.23/community" >> /sysroot/etc/apk/repositories && \
    apk --arch ${APK_ARCH} --root /sysroot --initdb --no-scripts \
        --allow-untrusted add \
        gcc \
        lua5.1-dev \
        luajit-dev \
        musl-dev \
        zlib-dev \
        zlib-static && \
    # If TARGET arch differs from CLANG_TARGET arch (e.g. i686 vs i586),
    # clang's GCC detection won't find the installation. Alias it.
    TARGET_ARCH=$(echo "${TARGET}" | cut -d- -f1) && \
    CLANG_ARCH=$(echo "${CLANG_TARGET}" | cut -d- -f1) && \
    if [ "${TARGET_ARCH}" != "${CLANG_ARCH}" ] && \
       [ -d "/sysroot/usr/lib/gcc/${CLANG_TARGET}" ]; then \
        ln -sf "${CLANG_TARGET}" "/sysroot/usr/lib/gcc/${TARGET_ARCH}-alpine-linux-musl"; \
    fi

# Create Clang wrapper scripts for C/C++ cross-compilation.
# These are used as the linker by Cargo, and as CC/CXX for -sys crates.
# --unwindlib=none: Rust provides its own unwinding via libunwind
RUN printf '#!/bin/sh\nexec clang --target=%s --sysroot=/sysroot -fuse-ld=lld --unwindlib=none -Wno-unused-command-line-argument "$@"\n' \
        "${TARGET}" > /usr/local/bin/cc-${TARGET} && \
    chmod +x /usr/local/bin/cc-${TARGET} && \
    printf '#!/bin/sh\nexec clang++ --target=%s --sysroot=/sysroot -fuse-ld=lld --unwindlib=none -Wno-unused-command-line-argument "$@"\n' \
        "${TARGET}" > /usr/local/bin/cxx-${TARGET} && \
    chmod +x /usr/local/bin/cxx-${TARGET}

ENV TARGET_CC=cc-${TARGET}
ENV TARGET_CXX=cxx-${TARGET}
ENV TARGET_AR=llvm-ar
ENV TARGET_RANLIB=llvm-ranlib
ENV TARGET_C_INCLUDE_PATH=/sysroot/usr/include

# pkg-config cross compilation support
ENV TARGET_PKG_CONFIG_ALLOW_CROSS=1
ENV TARGET_PKG_CONFIG_SYSROOT_DIR=/sysroot
ENV TARGET_PKG_CONFIG_PATH=/sysroot/usr/lib/pkgconfig
ENV TARGET_PKG_CONFIG_LIBDIR=/sysroot/usr/lib/pkgconfig

# We'll build our libraries in subdirectories of /home/rust/libs.
# Please clean up when you're done.
WORKDIR /home/rust/libs

# The Rust toolchain to use when building our image
ARG TOOLCHAIN=stable

# Install Rust toolchain and the musl target.
# Chmod 755 is set for root directory to allow access to execute binaries
# in /root/.cargo/bin (azure pipelines create own user).
#
# Remove docs and more stuff not needed in these images to make them smaller.
RUN chmod 755 /root/ && \
    curl https://sh.rustup.rs -sSf | \
    sh -s -- -y --profile minimal --default-toolchain ${TOOLCHAIN} && \
    (rustup target add ${TARGET} || rustup component add --toolchain ${TOOLCHAIN} rust-src) && \
    rustup component add --toolchain ${TOOLCHAIN} rustfmt clippy && \
    rm -rf /root/.rustup/toolchains/${TOOLCHAIN}-*/share/

# Configure Cargo to use our Clang wrapper as the linker for the target
RUN printf '[target.%s]\nlinker = "cc-%s"\n' "${TARGET}" "${TARGET}" \
    > /root/.cargo/config.toml

# Build std sysroot for targets that don't have an official std release
ADD build-sysroot /home/rust/src/build-sysroot
ADD build-std.sh .
RUN bash build-std.sh

ENV RUSTUP_HOME=/root/.rustup
ENV CARGO_HOME=/root/.cargo
ENV CARGO_BUILD_TARGET=${TARGET}

# Expect our source code to live in /home/rust/src
WORKDIR /home/rust/src

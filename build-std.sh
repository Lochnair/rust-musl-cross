#!/bin/bash
set -e

# Build a custom std sysroot for tier3 targets that don't have prebuilt
# std libraries available via `rustup target add`.
#
# This is only needed when TOOLCHAIN=nightly and the target is tier3
# (e.g. s390x-unknown-linux-musl). For tier1/2 targets, `rustup target add`
# provides prebuilt std and this script is a no-op.

# Only run for nightly toolchain on tier3 targets (those where rustup target add failed)
HOST=$(rustc -Vv | grep 'host:' | awk '{print $2}')
SYSROOT=$(rustc --print sysroot)

# Check if the target std library already exists (installed by rustup target add)
if [ -d "${SYSROOT}/lib/rustlib/${TARGET}/lib" ] && \
   ls "${SYSROOT}/lib/rustlib/${TARGET}/lib"/*.rlib 1> /dev/null 2>&1; then
  echo "std library for ${TARGET} already exists, skipping build-std"
  exit 0
fi

# Only nightly supports -Zbuild-std / rust-src
if [ "${TOOLCHAIN}" != "nightly" ]; then
  echo "Warning: Target ${TARGET} has no prebuilt std and toolchain is not nightly. Skipping."
  exit 0
fi

echo "Building std sysroot for tier3 target: ${TARGET}"

# Build and install the sysroot builder tool
cd /tmp
cp -r /home/rust/src/build-sysroot .
cd build-sysroot
cargo build --release

# Set RUSTFLAGS to point at the sysroot libraries
export RUSTFLAGS="-L/sysroot/usr/lib -L/sysroot/lib"

./target/release/build-sysroot "${TARGET}"

# Copy CRT objects from sysroot into rustlib for self-contained linking
mkdir -p "${SYSROOT}/lib/rustlib/${TARGET}/lib/self-contained"

# Copy musl CRT objects (crt1.o, crti.o, crtn.o, rcrt1.o, Scrt1.o)
if ls /sysroot/usr/lib/crt*.o 1> /dev/null 2>&1; then
  cp /sysroot/usr/lib/crt*.o "${SYSROOT}/lib/rustlib/${TARGET}/lib/self-contained/"
fi
if ls /sysroot/usr/lib/rcrt*.o 1> /dev/null 2>&1; then
  cp /sysroot/usr/lib/rcrt*.o "${SYSROOT}/lib/rustlib/${TARGET}/lib/self-contained/"
fi
if ls /sysroot/usr/lib/Scrt*.o 1> /dev/null 2>&1; then
  cp /sysroot/usr/lib/Scrt*.o "${SYSROOT}/lib/rustlib/${TARGET}/lib/self-contained/"
fi

# Cleanup
cd /tmp
rm -rf build-sysroot /root/.cargo/registry /root/.cargo/git

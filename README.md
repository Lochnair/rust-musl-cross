# rust-musl-cross

[![Docker Image](https://img.shields.io/docker/pulls/messense/rust-musl-cross.svg?maxAge=2592000)](https://hub.docker.com/r/messense/rust-musl-cross/)
[![Build](https://github.com/rust-cross/rust-musl-cross/workflows/Build/badge.svg)](https://github.com/rust-cross/rust-musl-cross/actions?query=workflow%3ABuild)

Docker images for compiling static Rust binaries using [musl-libc][], powered by
[Alpine Linux](https://alpinelinux.org/) and [Clang/LLD](https://clang.llvm.org/).

## How it works

`rust-musl-cross` uses Alpine Linux's package manager (`apk`) to create per-target
sysroots containing [musl-libc][] headers and libraries. [Clang][] is used as the
cross-compiler and [LLD][] as the linker — no per-target GCC toolchain needed.

This makes it easy to extend images with additional native libraries:

```dockerfile
FROM ghcr.io/rust-cross/rust-musl-cross:x86_64-musl
RUN apk --arch x86_64 --root /sysroot add openssl-dev openssl-libs-static
```

## Prebuilt images

The following [prebuilt Docker images](https://hub.docker.com/r/messense/rust-musl-cross/) are available
for x86\_64 (amd64) and aarch64 (arm64) host architectures.

### Stable toolchain

| Cross Compile Target               | Docker Image Tag      |
| ---------------------------------- | --------------------- |
| aarch64-unknown-linux-musl         | aarch64-musl          |
| arm-unknown-linux-musleabihf       | arm-musleabihf        |
| armv7-unknown-linux-musleabihf     | armv7-musleabihf      |
| i686-unknown-linux-musl            | i686-musl             |
| loongarch64-unknown-linux-musl     | loongarch64-musl      |
| powerpc64le-unknown-linux-musl     | powerpc64le-musl      |
| riscv64gc-unknown-linux-musl       | riscv64gc-musl        |
| s390x-unknown-linux-musl           | s390x-musl            |
| x86\_64-unknown-linux-musl         | x86\_64-musl          |

### Nightly toolchain

| Cross Compile Target               | Docker Image Tag             |
| ---------------------------------- | ---------------------------- |
| aarch64-unknown-linux-musl         | nightly-aarch64-musl         |
| arm-unknown-linux-musleabihf       | nightly-arm-musleabihf       |
| armv7-unknown-linux-musleabihf     | nightly-armv7-musleabihf     |
| i686-unknown-linux-musl            | nightly-i686-musl            |
| loongarch64-unknown-linux-musl     | nightly-loongarch64-musl     |
| powerpc64le-unknown-linux-musl     | nightly-powerpc64le-musl     |
| riscv64gc-unknown-linux-musl       | nightly-riscv64gc-musl       |
| s390x-unknown-linux-musl           | nightly-s390x-musl           |
| x86\_64-unknown-linux-musl         | nightly-x86\_64-musl         |

## Usage

To use `armv7-unknown-linux-musleabihf` target for example, first pull the image:

```bash
docker pull ghcr.io/rust-cross/rust-musl-cross:armv7-musleabihf
# Also available on Docker Hub
# docker pull messense/rust-musl-cross:armv7-musleabihf
```

Then you can do:

```bash
alias rust-musl-builder='docker run --rm -it -v "$(pwd)":/home/rust/src ghcr.io/rust-cross/rust-musl-cross:armv7-musleabihf'
rust-musl-builder cargo build --release
```

This command assumes that `$(pwd)` is readable and writable. It will output binaries in `armv7-unknown-linux-musleabihf`.
At the moment, it doesn't attempt to cache libraries between builds, so this is best reserved for making final release builds.

## Strip binaries

You can use `llvm-strip` inside the image to strip binaries:

```bash
docker run --rm -it -v "$(pwd)":/home/rust/src ghcr.io/rust-cross/rust-musl-cross:armv7-musleabihf llvm-strip /home/rust/src/target/release/example
```

[musl-libc]: http://www.musl-libc.org/
[Clang]: https://clang.llvm.org/
[LLD]: https://lld.llvm.org/

## License

Licensed under [The MIT License](./LICENSE)

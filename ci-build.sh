#!/bin/bash
cd "$(dirname "$0")"
source 'ci-library.sh'
mkdir artifacts
mkdir download

# Enable custom -next repos (this will break msys2 toolchains that use dll's)
cp -f pacman.conf /etc/pacman.conf
pacman --noconfirm -Scc
pacman --noconfirm -Sy
pacman -Syyw --noconfirm --cache=download "${MINGW_PACKAGE_PREFIX}-toolchain"
cp -v download/${MINGW_PACKAGE_PREFIX}-gcc*.xz artifacts/ || true
cp -v download/${MINGW_PACKAGE_PREFIX}-{clang,clang-analyzer,clang-tools-extra,compiler-rt,gcc-compat,lld,llvm,llvm-libs,libc++,openmp,libunwind,lldb,polly}-*.zst artifacts/ || true

# Prepare for deploy
cd artifacts || success 'All packages built successfully'
execute 'Updating pacman repository index' create_pacman_repository "${PACMAN_REPOSITORY}"
execute 'SHA-256 checksums' sha256sum *
success 'All artifacts built successfully'

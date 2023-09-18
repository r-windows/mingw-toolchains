#!/bin/bash
cd "$(dirname "$0")"
source 'ci-library.sh'
mkdir artifacts
mkdir sourcepkg

# Enable custom -next repos (this will break msys2 toolchains that use dll's)
cp -f pacman.conf /etc/pacman.conf
pacman --noconfirm -Scc
pacman --noconfirm -Sy

# Downgrades to be compatible with rtools
set_arch
pacman --noconfirm --needed -S git patch make unzip pactoys
pacman --noconfirm --needed -S mingw-w64-${_arch}-{cc,libtre,pkgconf,xz}
#wget -nv https://repo.msys2.org/mingw/${MINGW_ARCH}/mingw-w64-${_arch}-headers-git-10.0.0.r0.gaa08f56da-1-any.pkg.tar.zst
# if [ "$MINGW_ARCH" = "ucrt64" ]; then
# wget -nv https://repo.msys2.org/mingw/ucrt64/mingw-w64-${_arch}-gcc-12.2.0-9-any.pkg.tar.zst
# wget -nv https://repo.msys2.org/mingw/ucrt64/mingw-w64-${_arch}-gcc-fortran-12.2.0-9-any.pkg.tar.zst
# wget -nv https://repo.msys2.org/mingw/ucrt64/mingw-w64-${_arch}-gcc-libs-12.2.0-9-any.pkg.tar.zst
# wget -nv https://repo.msys2.org/mingw/ucrt64/mingw-w64-${_arch}-gcc-libgfortran-12.2.0-9-any.pkg.tar.zst
# else
# wget -nv https://repo.msys2.org/mingw/${MINGW_ARCH}/mingw-w64-${_arch}-clang-16.0.0-1-any.pkg.tar.zst
# wget -nv https://repo.msys2.org/mingw/${MINGW_ARCH}/mingw-w64-${_arch}-llvm-16.0.0-1-any.pkg.tar.zst
# wget -nv https://repo.msys2.org/mingw/${MINGW_ARCH}/mingw-w64-${_arch}-compiler-rt-16.0.0-1-any.pkg.tar.zst
# wget -nv https://repo.msys2.org/mingw/${MINGW_ARCH}/mingw-w64-${_arch}-lld-16.0.0-1-any.pkg.tar.zst
# wget -nv "https://repo.msys2.org/mingw/${MINGW_ARCH}/mingw-w64-${_arch}-libc%2B%2B-16.0.0-1-any.pkg.tar.zst"
# fi
#pacman -U --noconfirm *pkg.tar.zst
#rm -f *pkg.tar.zst

# Avoid libssp dependency
sed -i 's/-Wp,-D_FORTIFY_SOURCE=2//g' /etc/makepkg_mingw.conf
sed -i 's/-fstack-protector-strong//g' /etc/makepkg_mingw.conf

# Initiate git
#git_config user.email 'ci@msys2.org'
#git_config user.name  'MSYS2 Continuous Integration'
#git remote add upstream 'https://github.com/r-windows/rtools-next'
#git fetch --quiet upstream

# Detect changed packages
list_commits  || failure 'Could not detect added commits'
list_packages || failure 'Could not detect changed files'
message 'Processing changes' "${commits[@]}"
test -z "${packages}" && success 'No changes in package recipes'
define_build_order || failure 'Could not determine build order'

# Only build toolchains for appropriate targets
if [ "$MINGW_ARCH" == "ucrt64" ]; then
  if [ "${packages}" == "mingw-w64-clang" ] || [ "${packages}" == "mingw-w64-libc++" ]; then
    success "Skipping ${packages} for $MINGW_ARCH"
  fi
else
  if [ "${packages}" == "mingw-w64-gcc" ]; then
    success "Skipping ${packages} for $MINGW_ARCH"
  fi
fi

# Build
message 'Building packages' "${packages[@]}"
execute 'Approving recipe quality' check_recipe_quality

# Force static linking (breaks normal msys2 installation!)
#rm -f /mingw32/lib/*.dll.a
#rm -f /mingw64/lib/*.dll.a
#rm -fv /${MINGW_ARCH}/lib/*.dll.a
#ls -ltr /${MINGW_ARCH}/lib/*.a
#export PKG_CONFIG="/${MINGW_ARCH}/bin/pkg-config --static"
export PKGEXT='.pkg.tar.xz'

for package in "${packages[@]}"; do
    # Force static linking by removing import libs from deps
    #execute "Installing build dependencies for $package" makepkg-mingw -seoc --noconfirm
    #rm -fv /${MINGW_ARCH}/lib/*.dll.a

    execute 'Building binary' makepkg-mingw --noconfirm --noprogressbar --skippgpcheck --syncdeps --rmdeps --cleanbuild
    #MINGW_ARCH=mingw64 execute 'Building source' makepkg-mingw --noconfirm --noprogressbar --skippgpcheck --allsource
    execute 'List output contents' ls -ltr
    execute 'Installing' yes:pacman --noprogressbar --upgrade *.pkg.tar.xz
    execute 'Checking Binaries' find ./pkg -regex ".*\.\(exe\|dll\|a\|pc\)"
    execute 'Copying binary package' mv *.pkg.tar.xz ../artifacts
    #execute 'Copying source package' mv *.src.tar.gz ../sourcepkg
    unset package
done

# Prepare for deploy
cd artifacts || success 'All packages built successfully'
execute 'Updating pacman repository index' create_pacman_repository "${PACMAN_REPOSITORY}"
execute 'Generating build references'  create_build_references  "${PACMAN_REPOSITORY}"
execute 'SHA-256 checksums' sha256sum *
success 'All artifacts built successfully'

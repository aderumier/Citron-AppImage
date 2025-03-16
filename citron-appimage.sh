#!/bin/sh

set -ex

export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH="$(uname -m)"

REPO="https://git.citron-emu.org/Citron/Citron.git"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
URUNTIME="https://github.com/VHSgunzo/uruntime/releases/latest/download/uruntime-appimage-dwarfs-$ARCH"

if [ "$1" = 'v3' ]; then
	echo "Making x86-64-v3 optimized build of citron"
	ARCH="${ARCH}_v3"
	ARCH_FLAGS="-march=x86-64-v3 -O3"
else
	echo "Making x86-64 generic build of citron"
	ARCH_FLAGS="-march=x86-64 -mtune=generic -O3"
fi
UPINFO="gh-releases-zsync|$(echo "$GITHUB_REPOSITORY" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"

# BUILD CITRON, fallback to mirror if upstream repo fails to clone
if ! git clone 'https://git.citron-emu.org/Citron/Citron.git' ./citron; then
	echo "Using mirror instead..."
	rm -rf ./citron || true
	git clone 'https://github.com/pkgforge-community/git.citron-emu.org-Citron-Citron.git' ./citron
fi

(
	cd ./citron
	if [ "$DEVEL" = 'true' ]; then
		CITRON_TAG="$(git rev-parse --short HEAD)"
		echo "Making nightly \"$CITRON_TAG\" build"
		VERSION="$CITRON_TAG"
	else
		CITRON_TAG=$(git describe --tags)
		echo "Making stable \"$CITRON_TAG\" build"
		git checkout "$CITRON_TAG"
		VERSION="$(echo "$CITRON_TAG" | awk -F'-' '{print $1}')"
	fi
	git submodule update --init --recursive -j$(nproc)

	#Replaces 'boost::asio::io_service' with 'boost::asio::io_context' for compatibility with Boost.ASIO versions 1.74.0 and later
	find src -type f -name '*.cpp' -exec sed -i 's/boost::asio::io_service/boost::asio::io_context/g' {} \;

	mkdir build
	cd build
	cmake .. -GNinja \
		-DCITRON_USE_BUNDLED_VCPKG=OFF \
		-DCITRON_USE_BUNDLED_QT=OFF \
		-DUSE_SYSTEM_QT=ON \
		-DCITRON_USE_BUNDLED_FFMPEG=OFF \
		-DCITRON_USE_BUNDLED_SDL2=ON \
		-DCITRON_USE_EXTERNAL_SDL2=OFF \
		-DCITRON_TESTS=OFF \
		-DCITRON_CHECK_SUBMODULES=OFF \
		-DCITRON_USE_LLVM_DEMANGLE=OFF \
		-DCITRON_ENABLE_LTO=ON \
		-DCITRON_USE_QT_MULTIMEDIA=ON \
		-DCITRON_USE_QT_WEB_ENGINE=OFF \
		-DENABLE_QT_TRANSLATION=ON \
		-DUSE_DISCORD_PRESENCE=OFF \
		-DBUNDLE_SPEEX=ON \
		-DCITRON_USE_FASTER_LD=OFF \
		-DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_CXX_FLAGS="$ARCH_FLAGS -Wno-error" \
		-DCMAKE_C_FLAGS="$ARCH_FLAGS" \
		-DCMAKE_SYSTEM_PROCESSOR="$(uname -m)" \
		-DCMAKE_BUILD_TYPE=Release
	ninja
	sudo ninja install
	echo "$VERSION" >~/version
)

VERSION="$(cat ~/version)"

cd ..
./appimage-builder.sh citron ./citron/build

echo "All Done!"

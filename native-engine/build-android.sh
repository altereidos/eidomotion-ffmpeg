#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_ROOT="${ANDROID_SDK_ROOT:-$ROOT/.android-sdk}"
NDK_VERSION="27.2.12479018"
API="23"
FFMPEG_VERSION="9.0.2"
LAME_VERSION="3.100"
VPX_VERSION="1.15.2"
OPUS_VERSION="1.6.1"
WORK="$ROOT/native-engine/.work"
SOURCE_DIR="$ROOT/native-engine/sources"
OUTPUT_DIR="${NATIVE_PREBUILT_DIR:-$ROOT/src-capacitor/android/app/src/main/cpp/prebuilt}"
NDK="$SDK_ROOT/ndk/$NDK_VERSION"

if [[ ! -d "$NDK" ]]; then
  echo "Android NDK $NDK_VERSION is missing at $NDK" >&2
  exit 2
fi

HOST_TAG="darwin-arm64"
[[ -d "$NDK/toolchains/llvm/prebuilt/$HOST_TAG" ]] || HOST_TAG="darwin-x86_64"
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG"
if [[ ! -d "$TOOLCHAIN" ]]; then
  echo "No macOS NDK toolchain found in $NDK/toolchains/llvm/prebuilt" >&2
  exit 2
fi

JOBS="$(sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN || echo 4)"
mkdir -p "$SOURCE_DIR" "$WORK" "$OUTPUT_DIR"
FFMPEG_TARBALL="$SOURCE_DIR/ffmpeg-$FFMPEG_VERSION.tar.xz"
LAME_TARBALL="$SOURCE_DIR/lame-$LAME_VERSION.tar.gz"
VPX_TARBALL="$SOURCE_DIR/libvpx-$VPX_VERSION.tar.gz"
OPUS_TARBALL="$SOURCE_DIR/opus-$OPUS_VERSION.tar.gz"
[[ -f "$FFMPEG_TARBALL" ]] || curl -fL "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" -o "$FFMPEG_TARBALL"
[[ -f "$LAME_TARBALL" ]] || curl -fL "https://sourceforge.net/projects/lame/files/lame/$LAME_VERSION/lame-$LAME_VERSION.tar.gz/download" -o "$LAME_TARBALL"
# Gitiles +archive stamps tar members at download time, so its checksum changes
# for identical source. Use the tagged GitHub source archive for a stable pin.
[[ -f "$VPX_TARBALL" ]] || curl -fL "https://github.com/webmproject/libvpx/archive/refs/tags/v$VPX_VERSION.tar.gz" -o "$VPX_TARBALL"
[[ -f "$OPUS_TARBALL" ]] || curl -fL "https://downloads.xiph.org/releases/opus/opus-$OPUS_VERSION.tar.gz" -o "$OPUS_TARBALL"
echo "8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e  $FFMPEG_TARBALL" | shasum -a 256 -c -
echo "ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e  $LAME_TARBALL" | shasum -a 256 -c -
echo "26fcd3db88045dee380e581862a6ef106f49b74b6396ee95c2993a260b4636aa  $VPX_TARBALL" | shasum -a 256 -c -
echo "6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1  $OPUS_TARBALL" | shasum -a 256 -c -

mkdir -p "$WORK/source"
[[ -d "$WORK/source/ffmpeg-$FFMPEG_VERSION" ]] || tar -xf "$FFMPEG_TARBALL" -C "$WORK/source"
[[ -d "$WORK/source/lame-$LAME_VERSION" ]] || tar -xf "$LAME_TARBALL" -C "$WORK/source"
[[ -d "$WORK/source/opus-$OPUS_VERSION" ]] || tar -xf "$OPUS_TARBALL" -C "$WORK/source"
[[ -d "$WORK/source/libvpx-$VPX_VERSION" ]] || { mkdir -p "$WORK/source/libvpx-$VPX_VERSION"; tar -xf "$VPX_TARBALL" --strip-components=1 -C "$WORK/source/libvpx-$VPX_VERSION"; }

build_abi() {
  local abi="$1" triple host arch cpu vpxTarget
  case "$abi" in
    arm64-v8a) triple="aarch64-linux-android"; host="aarch64-linux-android"; arch="aarch64"; cpu="armv8-a"; vpxTarget="arm64-android-gcc" ;;
    armeabi-v7a) triple="armv7a-linux-androideabi"; host="arm-linux-androideabi"; arch="arm"; cpu="armv7-a"; vpxTarget="armv7-android-gcc" ;;
    x86_64) triple="x86_64-linux-android"; host="x86_64-linux-android"; arch="x86_64"; cpu="x86-64"; vpxTarget="x86_64-android-gcc" ;;
    x86) triple="i686-linux-android"; host="i686-linux-android"; arch="x86"; cpu="i686"; vpxTarget="x86-android-gcc" ;;
    *) echo "Unsupported ABI: $abi" >&2; return 2 ;;
  esac

  local abi_work="$WORK/$abi"
  local lame_src="$abi_work/lame-src"
  local opus_src="$abi_work/opus-src"
  local vpx_src="$abi_work/vpx-src"
  local ffmpeg_src="$abi_work/ffmpeg-src"
  local prefix="$abi_work/prefix"
  local dest="$OUTPUT_DIR/$abi"
  mkdir -p "$abi_work" "$dest"
  [[ -d "$lame_src" ]] || cp -R "$WORK/source/lame-$LAME_VERSION" "$lame_src"
  [[ -d "$ffmpeg_src" ]] || cp -R "$WORK/source/ffmpeg-$FFMPEG_VERSION" "$ffmpeg_src"
  [[ -d "$opus_src" ]] || cp -R "$WORK/source/opus-$OPUS_VERSION" "$opus_src"
  [[ -d "$vpx_src" ]] || cp -R "$WORK/source/libvpx-$VPX_VERSION" "$vpx_src"

  local cc="$TOOLCHAIN/bin/${triple}${API}-clang"
  local cxx="$TOOLCHAIN/bin/${triple}${API}-clang++"
  local ar="$TOOLCHAIN/bin/llvm-ar"
  local ranlib="$TOOLCHAIN/bin/llvm-ranlib"
  local strip="$TOOLCHAIN/bin/llvm-strip"

  if [[ ! -f "$prefix/lib/libmp3lame.a" ]]; then
    echo "Building libmp3lame $LAME_VERSION for $abi"
    (
      cd "$lame_src"
      CC="$cc" CXX="$cxx" AR="$ar" RANLIB="$ranlib" STRIP="$strip" \
        CFLAGS="-O3 -fPIC" \
        ./configure --host="$host" --prefix="$prefix" --enable-static --disable-shared \
        --disable-frontend --disable-decoder --disable-analyzer-hooks --disable-gtktest
      make -j"$JOBS"
      make install
    )
  else
    echo "Reusing libmp3lame $LAME_VERSION already built for $abi"
  fi

  if [[ ! -f "$prefix/lib/libopus.a" ]]; then
    echo "Building libopus $OPUS_VERSION for $abi"
    (
      cd "$opus_src"
      export CC="$cc" AR="$ar" RANLIB="$ranlib" CFLAGS="-O3 -fPIC"
      ./configure --host="$host" --prefix="$prefix" --enable-static --disable-shared \
        --disable-doc --disable-extra-programs --disable-asm
      make -j"$JOBS"
      make install
    )
  fi

  if [[ ! -f "$prefix/lib/libvpx.a" ]]; then
    echo "Building libvpx $VPX_VERSION for $abi"
    (
      cd "$vpx_src"
      CC="$cc" CXX="$cxx" AR="$ar" LD="$cc" AS="$cc" STRIP="$strip" \
        ./configure --target="$vpxTarget" --prefix="$prefix" \
        --enable-pic --enable-vp9 --disable-vp8 --disable-examples --disable-tools \
        --disable-docs --disable-unit-tests --extra-cflags="--sysroot=$TOOLCHAIN/sysroot -O3 -fPIC"
      python3 "$ROOT/native-engine/sanitize-build-config.py" "$vpx_src/vpx_config.c" \
        --replace "$prefix=<ABI_PREFIX>" \
        --replace "$TOOLCHAIN=<ANDROID_NDK_TOOLCHAIN>" \
        --replace "$SDK_ROOT=<ANDROID_SDK_ROOT>" \
        --replace "$ROOT=<PACKAGE_ROOT>"
      make -j"$JOBS"
      make install
    )
  fi

  echo "Building FFmpeg $FFMPEG_VERSION for $abi"
  (
    cd "$ffmpeg_src"
    PKG_CONFIG_PATH="$prefix/lib/pkgconfig" PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig" \
    ./configure \
      --prefix="$prefix" --target-os=android --arch="$arch" --cpu="$cpu" \
      --enable-cross-compile --sysroot="$TOOLCHAIN/sysroot" \
      --cc="$cc" --cxx="$cxx" --ar="$ar" --ranlib="$ranlib" --strip="$strip" \
      --enable-libmp3lame --enable-libvpx --enable-libopus --enable-pic --enable-static --disable-shared \
      --enable-jni --enable-mediacodec \
      --disable-asm \
      --enable-zlib \
      --disable-programs --disable-doc --disable-debug --disable-avdevice \
      --disable-avfilter --disable-network \
      --disable-encoders --enable-encoder=libmp3lame --enable-encoder=aac \
      --enable-encoder=pcm_s16le --enable-encoder=flac --enable-encoder=libvpx_vp9 --enable-encoder=libopus \
      --enable-encoder=h264_mediacodec --enable-encoder=vp9_mediacodec \
      --disable-muxers --enable-muxer=mp3 --enable-muxer=ipod --enable-muxer=wav --enable-muxer=flac \
      --enable-muxer=mp4 --enable-muxer=webm --enable-muxer=matroska \
      --enable-decoder=png --enable-decoder=webp \
      --enable-parser=png --enable-parser=webp \
      --enable-demuxer=image2 --enable-demuxer=png_pipe --enable-demuxer=webp_pipe \
      --disable-indevs --disable-outdevs --disable-autodetect \
      --extra-cflags="-O3 -fPIC -I$prefix/include" \
      --extra-ldflags="-L$prefix/lib" --extra-libs="-lm -lz -llog"
    python3 "$ROOT/native-engine/sanitize-build-config.py" "$ffmpeg_src/config.h" \
      --replace "$prefix=<ABI_PREFIX>" \
      --replace "$TOOLCHAIN=<ANDROID_NDK_TOOLCHAIN>" \
      --replace "$SDK_ROOT=<ANDROID_SDK_ROOT>" \
      --replace "$ROOT=<PACKAGE_ROOT>"
    make -j"$JOBS"
    make install
  )

  mkdir -p "$dest/include" "$dest/lib"
  cp -R "$prefix/include/." "$dest/include/"
  cp "$ffmpeg_src/config.h" "$dest/ffmpeg-config.h"
  cp "$prefix/lib/libavformat.a" "$prefix/lib/libavcodec.a" \
    "$prefix/lib/libswscale.a" "$prefix/lib/libswresample.a" "$prefix/lib/libavutil.a" \
    "$prefix/lib/libmp3lame.a" "$prefix/lib/libopus.a" "$prefix/lib/libvpx.a" "$dest/lib/"
  NM="$TOOLCHAIN/bin/llvm-nm" "$ROOT/native-engine/tests/check-android-ffmpeg-codecs.sh" "$dest/lib"
  echo "Built FFmpeg/LAME core for $abi at $dest"
}

if [[ "$#" -gt 0 ]]; then
  ABIS=("$@")
else
  ABIS=(arm64-v8a armeabi-v7a x86_64 x86)
fi
for abi in "${ABIS[@]}"; do build_abi "$abi"; done

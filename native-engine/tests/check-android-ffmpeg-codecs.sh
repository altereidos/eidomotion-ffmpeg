#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="${1:?usage: check-android-ffmpeg-codecs.sh <prebuilt-lib-dir>}"
NM="${NM:-llvm-nm}"
command -v "$NM" >/dev/null || { echo "Missing llvm-nm; cannot inspect Android FFmpeg prebuilts" >&2; exit 2; }

require_symbol() {
  local library="$1" symbol="$2"
  local symbols
  symbols="$($NM -g "$LIB_DIR/$library")"
  grep -Eq "[[:space:]]${symbol}$" <<<"$symbols" || {
    echo "Android FFmpeg prebuilt is missing ${symbol} in ${library}" >&2
    exit 1
  }
}

require_symbol libavcodec.a ff_png_decoder
require_symbol libavcodec.a ff_webp_decoder
require_symbol libavcodec.a ff_png_parser
require_symbol libavcodec.a ff_webp_parser
require_symbol libavformat.a ff_image2_demuxer
require_symbol libavformat.a ff_image_png_pipe_demuxer
require_symbol libavformat.a ff_image_webp_pipe_demuxer
echo "Android FFmpeg image codec prebuilts present: png/webp decoders, parsers and demuxers."

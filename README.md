# EidoMotion FFmpeg corresponding source

This repository contains the arm64-v8a corresponding-source and relinking materials for the EidoMotion Android releases:

| App | Version | Android versionCode | Bundle |
| --- | --- | ---: | --- |
| EidoMotion Extract | 1.0.0 | 37 | [corresponding source and relink materials](releases/1.0.0/lgpl-source-1.0.0-extract-arm64-v8a.tar.gz) |
| EidoMotion Cut | 1.0.0 | 38 | [corresponding source and relink materials](releases/1.0.0/lgpl-source-1.0.0-cut-arm64-v8a.tar.gz) |

Both variants use the same FFmpeg 9.0.2 arm64-v8a build. The bundles contain the exact pinned upstream source archives (FFmpeg, LAME, libvpx, and Opus), license texts, generated config, build script, static libraries and headers, the matching release `AudioEngine.cpp.o`, and the generated `libaudioengine.so` link command. They do not contain proprietary app source, signing keys, or credentials.

## Build inputs and configuration

- FFmpeg 9.0.2; upstream archive SHA-256: `8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e`.
- LAME 3.100; SHA-256: `ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e`.
- libvpx 1.15.2 (tag `v1.15.2`, commit `d168454ecd099805c675d4a98c66f4891373302a`); SHA-256: `26fcd3db88045dee380e581862a6ef106f49b74b6396ee95c2993a260b4636aa`.
- Opus 1.6.1; SHA-256: `6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1`.
- Android NDK r27c `27.2.12479018`, LLVM Clang `18.0.3`, Android API 23 target, ABI `arm64-v8a`; the release app used CMake `3.31.6`.
- The exact configure/build flags are in [`native-engine/build-android.sh`](native-engine/build-android.sh), with sanitized generated config in each bundle. No downstream FFmpeg patches are applied. The generated config verifies `CONFIG_GPL=0`, `CONFIG_VERSION3=0`, and `CONFIG_NONFREE=0`.

The source archives and build script are SHA-256 pinned. Each bundle also contains FFmpeg's `COPYING.LGPLv2.1`; the repository copy is [`LICENSE/COPYING.LGPLv2.1`](LICENSE/COPYING.LGPLv2.1). Additional notices are in [`NOTICE`](NOTICE), `native-engine/NOTICE.md`, and the bundle license directories.

## Rebuild native libraries

Install Android SDK/NDK 27.2.12479018 and run from the repository root:

```sh
ANDROID_SDK_ROOT=/path/to/android-sdk \
NATIVE_PREBUILT_DIR=/path/to/output/prebuilt \
bash native-engine/build-android.sh arm64-v8a
```

The script verifies all four upstream archive checksums before extraction. It downloads missing archives when run from this repository; each release bundle also contains the exact archives under `native-engine/sources/` for an offline source rebuild. `NATIVE_PREBUILT_DIR` receives an `arm64-v8a/` output directory containing the generated config, headers, and static libraries.

## Relink the app native library

FFmpeg and its codec libraries are statically linked into `libaudioengine.so`. Each per-app bundle provides the matching `relink/android-object/arm64-v8a/AudioEngine.cpp.o`, all linked static archives, headers, the exact generated `relink/LINK_COMMAND.txt`, and a tested `relink/relink.sh` helper. From a writable extraction of a bundle, run `ANDROID_SDK_ROOT=/path/to/android-sdk bash relink/relink.sh`. It stages the supplied object and archives at the paths expected by the recorded command, then invokes the NDK linker. This allows relinking without the proprietary application source.

## Reproduction evidence

The bundles were assembled against release commit `96b45131edd3ee9b871c980d60f04f604fe4f3b8`. Before public app distribution, the configured source URL must be accessible to recipients; repository visibility is controlled by the repository owner. Rebuilding the pinned sources from the current main source produced static archives matching the audited FFmpeg/LAME/libvpx/Opus arm64 build byte-for-byte. SHA-256 values:

| Archive | SHA-256 |
| --- | --- |
| `libavcodec.a` | `f71682bc0c544c6f9e11c6d10fb4a956dec47f500a3240b7bc28956988028703` |
| `libavformat.a` | `d909a9c903dcdf66a894799d406ec814b65b69443fcdf437bd4ac57741331638` |
| `libavutil.a` | `94d8ed36e4964299a6a30c5d094a815607c4431595050d9919350205866f567d` |
| `libswresample.a` | `c1a6a7fae167122c1f4dfb98f4a5edb41cd8ebe09d53588fa4253d7449dfc7b4` |
| `libswscale.a` | `44e103074d6bee025220f8afea07e1c0550f45cfc3355005c234b322fc911b51` |
| `libmp3lame.a` | `a6c6876eafe9f257cb0c80d792febd475b7d24266424aa5a495c89de47411236` |
| `libopus.a` | `bb74100de77a930bafb83d6a78de4876ff0ebcdf3ebb710064d85cdd7e3b393f` |
| `libvpx.a` | `149e63636afa0ba26e6882cec47d24d3952c5afaf930750f2622a4d2c7eb8dd9` |

The version and normalized FFmpeg configuration embedded in the release native library also match the audited build (`FFmpeg 9.0.2`, `Lavc 63.1.102`). The release AAB's embedded native library was checked for license configuration and decoder symbols; its hash is not claimed to be byte-identical to the freshly reproduced shared library.

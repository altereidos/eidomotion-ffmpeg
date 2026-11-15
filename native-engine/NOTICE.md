# Native engine notices

The Android native engine statically links FFmpeg 9.0.2, LAME 3.100, libvpx 1.15.2, and Opus 1.6.1. Network protocols and FFmpeg command-line programs are disabled. The script `native-engine/build-android.sh` verifies each bundled source archive against these SHA-256 values before extraction:

| Source archive | SHA-256 | License notice in archive |
| --- | --- | --- |
| `sources/ffmpeg-9.0.2.tar.xz` | `8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e` | `COPYING.LGPLv2.1`, `COPYING.LGPLv3`, `COPYING.GPLv2`, `COPYING.GPLv3` |
| `sources/lame-3.100.tar.gz` | `ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e` | `COPYING` (GNU Library General Public License v2) |
| `sources/libvpx-1.15.2.tar.gz` | `26fcd3db88045dee380e581862a6ef106f49b74b6396ee95c2993a260b4636aa` | `LICENSE`, `PATENTS` |
| `sources/opus-1.6.1.tar.gz` | `6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1` | `COPYING` |

For libvpx, `build-android.sh` downloads the GitHub source archive for tag `v1.15.2` and verifies its stable archive checksum. Do not substitute the Gitiles `+archive` endpoint: it emits the same tagged files with tar member timestamps set at request time, so the archive hash changes between downloads even when file contents match. The tag resolves to commit `d168454ecd099805c675d4a98c66f4891373302a`.

FFmpeg is distributed under LGPL 2.1 or later unless GPL options are enabled; the checked native configuration uses `CONFIG_GPL=0`. LAME's library is LGPL v2. libvpx and Opus include BSD style license terms. The libvpx archive also carries its patent notice. The complete license terms and copyright statements are preserved in the source archives above. Reproduce the applicable notices when redistributing the native engine or APK.

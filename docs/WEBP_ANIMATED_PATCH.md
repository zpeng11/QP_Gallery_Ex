# WebP Animated Patch

This repository stores WebP animation support as a patch series so the result can be rebuilt from a clean APK baseline.
It now includes a dedicated animated-webp runtime (JNI + Kotlin/Java runtime) for pre-Android-28 playback.

## Scope

Patch file:
- `patches/webp-animated.patch`

Changed smali files:
- `decoded/smali/com/alensw/ui/c/as.smali`
- `decoded/smali/com/alensw/ui/c/dp.smali`
- `decoded/smali/com/alensw/a/at.smali`
- `decoded/smali/com/alensw/b/h/r.smali` (added)
- `decoded/smali/com/alensw/b/h/t.smali` (added, runtime-backed decoder for pre-28)
- `decoded/smali/com/alensw/b/h/u.smali` (added, frame scheduler runnable)
- `decoded/smali/com/alensw/b/h/v.smali` (added, background decode worker)

Runtime payload source:
- `third_party/webp-runtime/1.0.8/classes2.dex`
- `third_party/webp-runtime/1.0.8/lib/armeabi/*.so`
- `third_party/webp-runtime/1.0.8/lib/x86/*.so`

## Behavior

- Animated WebP is enabled for large-image viewer tasks.
- Thumbnails remain static (no animation scheduling for preview path).
- MIME checks support both `image/webp` and `image/x-webp`.
- API 28+ uses `ImageDecoder` (`com/alensw/b/h/r`).
- API < 28 uses dedicated runtime (`com/alensw/b/h/t`) backed by `webp-android` JNI.
- API < 28 animation detection uses multi-signal probing:
  - `decodeInfo().hasAnimation`
  - `decodeInfo().frameCount > 1`
  - fallback probe via `hasNextFrame()` after first-frame decode
- API < 28 animation uses background decode + UI-thread frame consume, with real-time scheduling (drop stale frames instead of global slow playback).
- Runtime failures automatically fall back to static decode path.
- Runtime payload injection is deterministic and checksum-validated.
- Large GIF/WebP decode tasks now drive a visible loading indicator (`cx.i(true)` / action-bar progress) during async decode; it is hidden when the current frame is bound or pending tasks are cancelled.

## Diagnostics

- Loader chain logs are emitted under `WebpMovie`:
  - `try WebP runtime decoder (preferred)`
  - `fallback to WebP ImageDecoder path` (API 28+ only)
  - `fallback to static bitmap decode for WebP`
- Runtime decoder logs are emitted under `WebpRuntime`:
  - `decodeInfo hasAnimation=..., frameCount=..., size=...`
  - `animation inferred by hasNextFrame`
  - `runtime decoder reports non-animated webp after multi-signal probe`

## Regression Samples

- `does_animate.webp` (61 frames): expected to animate.
- `does_not_animate.webp` (458 frames): expected to animate.

## Reproducible Workflow

Run full baseline + patch + build + runtime-inject + sign:

```bash
make rebuild-patched
```

Source URL file is configurable via `SOURCE_URL_FILE` (default `original/stable.url`), then fetched into a version-aware filename such as `original/stable-9.7.apk`.

Manual equivalent:

```bash
./scripts/fetch_source_apk.sh \
  ./original/stable.url \
  ./original
APK_PATH="$(./scripts/resolve_source_apk_path.sh ./original/stable.url ./original)"
./scripts/prepare_baseline.sh "$APK_PATH" ./decoded
./scripts/apply_patches.sh . ./patches/series
./scripts/build.sh ./decoded ./build/stable-rebuilt-unsigned.apk
./scripts/prepare_webp_runtime.sh
./scripts/inject_webp_runtime.sh ./build/stable-rebuilt-unsigned.apk
./scripts/sign.sh ./build/stable-rebuilt-unsigned.apk \
  ./build/stable-rebuilt-aligned.apk \
  ./build/stable-rebuilt-signed.apk
```

## Verification

Check patch markers and runtime payload:

```bash
make verify-patch
```

Runtime validation:
- Open an animated WebP in large-image viewer and confirm playback.
- On Android 8.1, confirm playback cadence is close to real-time (no global slow-motion behavior).
- Confirm `WebpRuntime` logs appear for pre-28 playback.

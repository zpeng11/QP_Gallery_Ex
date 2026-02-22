# WebP Animated Patch

This repository stores WebP animation support as a patch series so the result can be rebuilt from a clean APK baseline.

## Scope

Patch file: `patches/webp-animated.patch`

Changed smali files:
- `decoded/smali/com/alensw/ui/c/as.smali`
- `decoded/smali/com/alensw/ui/c/dp.smali`
- `decoded/smali/com/alensw/a/at.smali`
- `decoded/smali/com/alensw/b/h/r.smali` (added)

## Behavior

- Animated WebP is enabled for large-image viewer tasks.
- Thumbnails remain static (no animation scheduling for preview path).
- MIME checks support both `image/webp` and `image/x-webp`.
- Decoder compatibility uses `ImageDecoder.createSource(File)` and avoids `AnimatedImageDrawable.getDuration()` to prevent vendor API mismatch crashes.

## Reproducible Workflow

Run full baseline + patch + build + sign:

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
./scripts/sign.sh ./build/stable-rebuilt-unsigned.apk \
  ./build/stable-rebuilt-aligned.apk \
  ./build/stable-rebuilt-signed.apk
```

## Verification

Check patch markers in decoded smali:

```bash
make verify-patch
```

Runtime validation:
- Open an animated WebP in large-image viewer and confirm playback.
- Confirm no `WebpMovie NoSuchMethodError` in `adb logcat`.

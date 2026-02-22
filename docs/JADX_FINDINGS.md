# APK JADX Findings

Manual notes moved from `analysis/` to `docs/` so `analysis/` can stay machine-generated.

## APK Metadata
- Package: `com.alensw.PicFolder`
- Version: `9.7` (`versionCode=9700000`)
- Min SDK: `23`
- App label: `Gallery`
- Launcher activity: `com.alensw.PicFolder.GalleryActivity`

## Rebuild Notes
- `apktool b` with legacy `aapt1` fails on resource symbol parsing.
- `apktool b --use-aapt2` is required and already enforced by `scripts/build.sh`.

## Functional Findings
- Gallery supports media view/edit/crop/wallpaper flows via exported intent filters.
- Transfer/cloud modules exist (`com.alensw.transfer`, `com.alensw.cloud`).
- Native helpers are present (`com.alensw.jni.JniUtils` and bundled `.so` libs).

## Patch-Related Findings
- WebP animation support is maintained as patch series under `patches/`.
- Runtime compatibility fix uses `ImageDecoder.createSource(File)` and avoids
  `AnimatedImageDrawable.getDuration()` due to vendor API mismatch risk.

## Security/Behavior Notes
- Requests broad storage/network permissions.
- Includes updater paths and install-package capability.
- Mixed obfuscation means some methods must be validated in smali.

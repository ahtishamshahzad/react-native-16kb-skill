# React Native Native-Dependency 16KB Compatibility Matrix

Quick reference for common RN packages that ship native (`.so`) code. Use it to know **which version first supports 16KB**, then **verify the actual `.so`** with `scripts/check_elf_alignment.sh` — versions move, and this table is a starting point, not proof.

> **Rule:** never mark a dependency "compatible" from this table alone. Confirm against the package's CHANGELOG/release notes **and** an alignment check of the built `.so`. Treat anything unverified as a risk in your report.

## Core / toolchain

| Component | 16KB-ready from | Notes |
|-----------|-----------------|-------|
| React Native | 0.73+ generally OK; **0.77+** best | Newer RN pulls AGP/NDK that align libs automatically. Hermes `.so` aligned via the RN-bundled NDK. |
| Android Gradle Plugin (AGP) | **8.5.1+** (8.7+ preferred) | Auto-aligns uncompressed `.so` to 16KB. The single most important lever. |
| Android NDK | **r27+**, prefer **r28+** | r28 defaults to 16KB. With r27 or lower + your own native code, add the linker flags. |
| Hermes | Bundled with RN | Aligned by the NDK that RN uses; tied to your RN version. |

## Common native modules

| Package | 16KB notes | Verify |
|---------|------------|--------|
| `react-native-reanimated` | 3.6+ tracks 16KB; use the latest 3.x. Common crash culprit (`libreanimated.so`). | Check `.so` align. |
| `react-native-gesture-handler` | 2.14+ recent builds OK. | Check `.so` align. |
| `react-native-screens` | 3.29+ recent builds OK. | Check `.so` align. |
| `react-native-vision-camera` | 3.9+/4.x ship 16KB-aligned native code; older 2.x risky. | Check `.so` align. |
| `react-native-maps` | Depends on bundled Play Services Maps; recent versions OK. | Check `.so` align. |
| `react-native-video` | ExoPlayer-based; recent 6.x OK, older builds risky. | Check `.so` align. |
| `react-native-fast-image` | Native image lib; use latest. | Check `.so` align. |
| Firebase (`@react-native-firebase/*`) | Recent (20.x+) align via updated Play Services. | Check `.so` align. |
| ML Kit / TFLite modules | TFLite native libs historically 4KB on old versions — high risk. | **Verify carefully.** |
| BLE (`react-native-ble-plx`, `react-native-ble-manager`) | Recent versions OK; older risky. | Check `.so` align. |
| Payments (Stripe, Razorpay, etc.) | SDK-dependent; many ship `.so`. Confirm the SDK's own 16KB statement. | **Verify with vendor.** |
| OpenCV / FFmpeg / libsodium / SQLite native builds | Frequently NOT aligned on older releases — common failures. | **Verify carefully.** |

## How to inspect what's actually in your build

```bash
# 1) list every .so in the release APK
unzip -l android/app/build/outputs/apk/release/app-release.apk | grep '\.so$'

# 2) align-check them all (uses the vendored script)
bash scripts/check_elf_alignment.sh android/app/build/outputs/apk/release/app-release.apk

# 3) map a .so back to a dependency (find which node_module owns it)
grep -rl "libreanimated" node_modules/*/android 2>/dev/null
```

## When a dependency is the blocker

1. Upgrade to the first version whose CHANGELOG states 16KB support.
2. If none exists, open/track an issue with the maintainer and note it as a release risk.
3. Do **not** ship and claim compliance while a misaligned `.so` is present — Play Console will flag it and 16KB devices may crash.

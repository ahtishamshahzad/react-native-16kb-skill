---
name: android-16kb-page-size-support
title: React Native Android 16KB Page Size Support
description: Audit, implement, and validate Android 16KB memory page size support in a React Native Android project. Use when an app shows the Play Console "16 KB page size" warning, crashes on 16KB-page (Android 15+, 64-bit) devices, or must be made compliant before publishing/updating.
version: 2.0.0
platform: react-native-android
tags: [react-native, android, gradle, agp, ndk, native-libraries, google-play, compliance, build, validation]
compatible_with: [claude-code, cursor, windsurf, antigravity, cline, generic-agent]
---

# React Native Android — 16KB Page Size Support

> **Scope:** This skill is specifically for **React Native Android** projects (a JS/TS app with an `android/` native project and `package.json`). It is not a generic Android guide.

## 1. Purpose

Google Play requires apps and updates **targeting Android 15+ (API 35) on 64-bit devices** to support **16KB memory page sizes**. Devices are moving from 4KB to 16KB pages; native code (`.so` libraries) built/packaged for 4KB pages can **crash on launch** or **block publishing**.

This skill helps an AI agent:

- **Audit** an existing React Native Android project for 16KB readiness.
- **Determine if the app is affected** (does it ship `.so` files on arm64-v8a / x86_64?).
- **Update the Android build config safely** (AGP, Gradle wrapper, NDK, packaging).
- **Verify native dependency compatibility** (Reanimated, Gesture Handler, camera, maps, video, audio, BLE, Firebase, ML, payment SDKs, etc.).
- **Build** APK and AAB.
- **Validate** real 16KB support using `zipalign`, `bundletool`, and a 16KB emulator/device.
- **Produce a clear, client-ready report.**

**Use this skill when:**

- Play Console shows *"Your app isn't 16 KB compatible."*
- The app crashes only on a 16KB system image (often `UnsatisfiedLinkError` in a `.so`).
- You are auditing an RN project before a release that targets API 35+.

---

## 2. Background: What Actually Makes an RN App 16KB-Compliant

Read this before editing anything. Compliance is achieved in priority order:

1. **Every bundled `.so` is ELF-aligned to 16KB (`2**14` = 16384).** This is the real, measurable requirement. It comes from:
   - **AGP 8.5.1+** — aligns uncompressed `.so` to 16KB automatically (8.7+ preferred).
   - **NDK r27+ (prefer r28+)** for any C/C++ compiled in the project (r28 defaults to 16KB).
   - **`useLegacyPackaging = false`** — stores `.so` uncompressed and page-aligned in the APK/AAB.
   - **Third-party `.so` built for 16KB** — you cannot realign a vendor's misaligned `.so` from Gradle; the dependency must ship a fixed version.
2. **NDK linker flags (only when compiling native code with NDK r27 or lower):**
   `-Wl,-z,max-page-size=16384` and `-Wl,-z,common-page-size=16384`. Not needed if the dependency/toolchain already produces 16KB libs (NDK r28+).
3. **`targetSdk` / `compileSdk` 35** so Google evaluates the app under the new rules.
4. **Verification** with build tooling — the only proof (Section 7).

> The `android.app.supports_16kb_page_size` manifest meta-data flag is **not** Google's official compliance mechanism and must not be presented as the fix. `android:max_aspect` is aspect-ratio and **unrelated** to page size — never add it as a "16KB" change. Real validation = `.so` alignment + `zipalign`/`bundletool`/emulator checks.

---

## 3. Input Requirements

Detect from the repo first; ask **only** for blocking unknowns.

| # | Input | Required? | Where to find it |
|---|-------|-----------|------------------|
| 1 | Confirm it's a React Native project | Yes | `package.json` with `react-native`, plus `android/`. |
| 2 | AGP version | Yes | `android/build.gradle` (classpath / plugins) or `android/settings.gradle`. |
| 3 | Gradle wrapper version | Yes | `android/gradle/wrapper/gradle-wrapper.properties`. |
| 4 | NDK version / whether NDK is used | Yes | `ndkVersion` in `android/build.gradle` or `android/app/build.gradle`; `local.properties`. |
| 5 | `compileSdk` / `targetSdk` | Yes | `android/app/build.gradle` (or RN root `build.gradle` ext block). |
| 6 | Native dependencies | Yes | `package.json` + `yarn.lock`/`package-lock.json`; `.so` files in build outputs. |
| 7 | Build flavors / variants / signing | Yes (to protect) | `android/app/build.gradle`. |
| 8 | Warning text or crash log | Helpful | Play Console / `adb logcat`. |
| 9 | Can the user build? Has a 16KB emulator? | Helpful | Ask if unstated. |

If only "make my RN app 16KB compliant" is given, proceed with documented best-practice assumptions and state them.

---

## 4. Files To Review (when present)

The agent must inspect these before proposing changes:

- `android/build.gradle` — AGP classpath, `ext` versions (SDK, NDK, Kotlin).
- `android/app/build.gradle` — packaging, ABI, signing, flavors, NDK.
- `android/gradle.properties` — `reactNativeArchitectures`, Hermes/new-arch flags.
- `android/settings.gradle` — plugin management / AGP plugin version.
- `android/app/src/main/AndroidManifest.xml` — confirm no fake/unsupported metadata.
- `gradle/wrapper/gradle-wrapper.properties` — Gradle version vs AGP compatibility.
- `package.json` — RN version + native-module dependencies.
- `yarn.lock` / `package-lock.json` — exact resolved versions of native modules.

---

## 5. Skill Instructions (Step by Step)

### Step 1 — Detect project & toolchain
- Confirm React Native (`package.json`). Record RN version, new-arch on/off (Fabric/TurboModules), Hermes on/off.
- Read all files in Section 4. Record AGP, Gradle wrapper, NDK, compileSdk, targetSdk.

### Step 2 — Determine if the app is affected
- Does it produce `.so` files for `arm64-v8a` / `x86_64`? (RN + Reanimated/Hermes almost always do.) If yes → affected.
- If the app has **no** native libs at all (rare for RN), it is unaffected — say so and stop.

### Step 3 — AGP & Gradle wrapper
- Check AGP version. **Prefer 8.5.1+** (8.7+ ideal).
- **Do not blindly upgrade AGP** — it can break an RN project. If an upgrade is needed, also bump the **Gradle wrapper** to a compatible version and warn about RN/Kotlin compatibility and CI impact. Name the exact version jump and its risk before changing.

### Step 4 — NDK
- Check whether the project uses NDK and its version. **Prefer r28+.**
- If the project compiles native code with **NDK r27 or lower**, add the linker flags where the compiled module is configured:
  ```gradle
  externalNativeBuild {
      cmake {
          arguments "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON"
          cppFlags "-Wl,-z,max-page-size=16384", "-Wl,-z,common-page-size=16384"
      }
  }
  ```
  Only add these if the project actually compiles `.so` itself. Skip if the toolchain/deps already produce 16KB libs (NDK r28+).

### Step 5 — Packaging configuration
In `android/app/build.gradle`, store native libs uncompressed/aligned. **Match the project's existing DSL** (`packaging {}` for newer AGP, `packagingOptions {}` for older):
```gradle
android {
    // ...
    packagingOptions {   // or `packaging` on newer AGP — match the project
        jniLibs {
            useLegacyPackaging = false   // uncompressed, 16KB-aligned .so
        }
    }
}
```
- Understand the build paths:
  - **Uncompressed libs** (`useLegacyPackaging = false`) → page-aligned, required for 16KB.
  - **Compressed libs** (`true`) → not aligned; avoid for release.
  - **APK** vs **AAB**: validate both, but the **Play-Console-generated APKs from your AAB** are what users get — always validate the AAB and ideally an APK extracted from it via bundletool.
- **Do not add config that isn't required** for the current AGP/Gradle/RN version.

### Step 6 — Audit native dependencies
- From `package.json` + lockfile, list every dependency that ships native code. Pay special attention to:
  - `react-native-reanimated`, `react-native-gesture-handler`, `react-native-screens`
  - camera (`react-native-vision-camera`, CameraX), maps (`react-native-maps`), video/audio players
  - payment SDKs (Stripe, Razorpay, etc.), Firebase, ML (TFLite, MLKit), BLE, image/crypto libs, OpenCV/FFmpeg/SQLite native builds
- For each: confirm a 16KB-aligned version exists (changelog/release notes/verified `.so`). **Bump where needed.** **Never claim a dependency is compatible without evidence**; flag unknowns as risks.

### Step 7 — Build
```bash
cd android
./gradlew clean
./gradlew assembleRelease   # APK
./gradlew bundleRelease     # AAB (preferred for Play)
```

### Step 8 — VALIDATE alignment (mandatory — the only proof)
```bash
# APK: every native lib must be page-aligned to 16KB
zipalign -c -P 16 -v 4 app/build/outputs/apk/release/app-release.apk

# AAB: confirm 16KB page alignment in the bundle config
bundletool dump config --bundle=app/build/outputs/bundle/release/app-release.aab | grep -i alignment
# Expected to include:
#   PAGE_ALIGNMENT_16K

# Per-.so deep check (optional, from an unzipped APK):
#   llvm-objdump -p libXXX.so | grep LOAD   → align must be 2**14 (16384)
```
- If `zipalign` reports a misaligned lib, or `bundletool` does not show `PAGE_ALIGNMENT_16K`, the app is **not** compliant. Fix the responsible dependency/toolchain — do **not** report success.

### Step 9 — Emulator / device validation
```bash
# On a 16KB Android 15+ emulator or device:
adb shell getconf PAGE_SIZE
# Expected:
#   16384
```
- Install the release build on that target, launch, and watch `adb logcat` for `UnsatisfiedLinkError` / page-size crashes.
- Set up a 16KB target via Android Studio Device Manager (Android 15 "16 KB" system images) if the user doesn't have one.

### Step 10 — Report
Produce the Output Format (Section 7) with all evidence.

---

## 6. Execution Workflow

```
1. Understand the request   → compliance, crash fix, or pre-release audit
2. Analyze the project       → RN version, AGP/Gradle/NDK/SDK, native deps, flavors/signing
3. Identify missing details  → ask ONLY blocking questions
4. Create a plan             → toolchain → packaging → deps → build → validate (ordered)
5. Execute the task          → surgical edits, version bumps, build
6. Validate the result       → zipalign + bundletool + getconf PAGE_SIZE — REQUIRED
7. Provide final summary      → client-ready report with evidence + remaining risks
```

---

## 7. Output Format

After running the skill, respond using exactly this structure:

```
## Summary
<What was reviewed and changed; whether the app is verified 16KB-compatible.>

## Files Changed
- path/to/file — what changed and why

## Compatibility Status
<"Verified 16KB compatible (evidence below)" | "Config applied, needs device/emulator verification" | "Blocked: dependency X ships a 4KB .so">

## Validation Commands Run
- <command> → <result>
  (zipalign output, bundletool PAGE_ALIGNMENT_16K, getconf PAGE_SIZE = 16384, etc.)

## Remaining Risks
- <dependency / SDK / Gradle / NDK / Play Console risk still to confirm>

## Next Steps
- Test on an Android 15+ 16KB emulator/device
- Upload the AAB to Play Console internal testing
- Check Play Console → App Bundle Explorer for the 16KB status
- Confirm the "16 KB" warning is removed
```

---

## 8. Rules and Constraints

The agent **must** obey these.

**Do:**
1. Prioritize real `.so` 16KB alignment over cosmetic flags.
2. Verify compliance with `zipalign` / `bundletool` / emulator — never from "the build passed."
3. Audit dependencies with evidence; bump where needed.
4. Follow the project's existing DSL (`packaging` vs `packagingOptions`, Groovy vs Kotlin) and RN conventions.
5. Make surgical, minimal edits; comment only where useful.
6. Check the Gradle build (and `tsc`/lint if a JS layer is touched) after edits.
7. State which AGP/NDK/RN versions your advice assumes.
8. Proceed with documented best-practice assumptions when info is sufficient; ask only blocking questions.

**Do NOT:**
1. Remove working code without explaining why and offering a safer path.
2. Blindly upgrade React Native, Gradle, AGP, Kotlin, or NDK — name the jump and its risk first; check Gradle-wrapper compatibility on any AGP change.
3. Add fake/unsupported manifest flags (`android.app.supports_16kb_page_size` as "the fix"), or bundle in unrelated settings like `android:max_aspect`.
4. Claim 16KB support just because the build succeeds.
5. Claim all dependencies are compatible without checking each one.
6. Ignore `.so` libraries.
7. Break existing build variants, flavors, signing configs, or CI/CD.
8. Change the app package name, version code, signing config, or keystore settings unless explicitly requested.

---

## 9. Validation Checklist

Complete **every** item and state pass/fail before the final response.

- [ ] Android build files reviewed (`build.gradle` x2, `gradle.properties`, `settings.gradle`, manifest, wrapper, `package.json`, lockfile).
- [ ] AGP version checked (≥ 8.5.1 preferred).
- [ ] Gradle wrapper checked (compatible with AGP).
- [ ] NDK version checked (≥ r28 preferred; linker flags added only if compiling with r27 or lower).
- [ ] Native `.so` libraries checked.
- [ ] React Native native dependencies reviewed with evidence; unknowns flagged.
- [ ] `jniLibs { useLegacyPackaging = false }` set, matching project DSL.
- [ ] Release APK build completed (`assembleRelease`).
- [ ] Release AAB build completed (`bundleRelease`).
- [ ] `zipalign -c -P 16 -v 4` validation completed.
- [ ] `bundletool dump config` shows `PAGE_ALIGNMENT_16K`.
- [ ] 16KB emulator/device test documented (`adb shell getconf PAGE_SIZE` → `16384`).
- [ ] Play Console verification steps (App Bundle Explorer) provided.
- [ ] No unsupported manifest metadata or unrelated settings added.
- [ ] No package name, version code, signing, or keystore change made (unless explicitly requested).
- [ ] No build variants, flavors, signing, or CI/CD broken.
- [ ] Final explanation is clear, honest about risks, and client-ready.

---

## 10. Testing Requirements

Test, or give the developer clear instructions to test, on a 16KB Android 15+ target:

- App launch (cold start).
- Login / signup flow.
- Main navigation across tabs/stacks.
- Screens that use native modules.
- Camera / media features (if present).
- Maps / location (if present).
- Push notifications (if present).
- Payment SDK screens (if present).
- Any feature backed by a native dependency.
- Release **APK** and **AAB** builds both produced.
- Play Console **App Bundle Explorer** confirms 16KB status after upload.

---

## 11. Example Usage

**Example 1 — Fix the Play Console warning**
> "Play Console says my React Native app isn't 16 KB compatible. The `android` folder is here — audit it, apply the needed config, build a release AAB, and show me how to verify before re-uploading."

**Example 2 — Diagnose a launch crash**
> "My RN app crashes on a Pixel with a 16KB system image — `UnsatisfiedLinkError` on `libreanimated.so`. Find the misaligned native libs, fix the build, and confirm it launches."

**Example 3 — Full pre-release audit**
> "Before our Android 15 release, audit this React Native project for 16KB compliance: AGP/Gradle/NDK versions, every native dependency (camera, maps, payments, Reanimated, Firebase), then build and validate with zipalign and bundletool and give me a client-ready report."

---

## 12. Notes on Accuracy

Corrections baked into this skill versus common (incorrect) write-ups:

- **`.so` 16KB alignment is the requirement**, produced by AGP 8.5.1+ / NDK r28+ / `useLegacyPackaging = false` — not by a manifest flag. `android.app.supports_16kb_page_size` is not Google's compliance mechanism; `android:max_aspect` is unrelated (aspect ratio).
- **"Build succeeded" is not proof.** Only `zipalign -c -P 16`, `bundletool dump config` (`PAGE_ALIGNMENT_16K`), and `getconf PAGE_SIZE = 16384` on a 16KB target prove compliance.
- **Dependencies are not assumed compatible** — each native module is verified with evidence; unknowns are flagged as risks.

# AGENTS.md — React Native Android 16KB Page Size Support

This file tells any AI coding agent (Claude Code, Cursor, Windsurf, Antigravity, Cline, or any agent-based IDE) how to behave when the **android-16kb-page-size-support** skill is active. Read it together with `SKILL.md`.

> **Scope:** React Native Android projects only (a `package.json` with `react-native` plus an `android/` native project).

---

## Core Behavior When This Skill Is Active

1. **The goal is `.so` 16KB ELF alignment — not a manifest flag.**
   Compliance = every native library aligned to 16KB (`2**14` = 16384), produced by **AGP 8.5.1+**, **NDK r28+** (for compiled code), and **`useLegacyPackaging = false`**. Never present `android.app.supports_16kb_page_size` as the fix; never add `android:max_aspect` (it is aspect-ratio, unrelated).

2. **Never report success without validation.**
   A green build is not proof. Required evidence:
   - `zipalign -c -P 16 -v 4 app-release.apk` → no misaligned libs
   - `bundletool dump config --bundle=app-release.aab | grep -i alignment` → includes `PAGE_ALIGNMENT_16K`
   - `adb shell getconf PAGE_SIZE` on a 16KB target → `16384`
   If you cannot run these, give the exact commands and mark the result "unverified until run."

3. **Make surgical edits only.**
   Touch the minimum: Gradle packaging, AGP/Gradle/NDK versions, SDK levels, dependency bumps, and (only if compiling native code with NDK ≤ r27) linker flags. No refactors, no reformatting.

4. **Protect the project.**
   Do not break build variants, flavors, signing configs, or CI/CD. Do not change package name, version code, signing config, or keystore settings unless explicitly requested.

5. **Audit RN native dependencies with evidence.**
   From `package.json` + lockfile, list native-code packages (Reanimated, Gesture Handler, Screens, camera, maps, video/audio, payments, Firebase, ML, BLE, OpenCV/FFmpeg/SQLite). Only call one "compatible" with a citation; flag unknowns as risks.

6. **Be careful and honest with upgrades.**
   Do not blindly upgrade RN, Gradle, AGP, Kotlin, or NDK. If an AGP upgrade is needed, also bump the Gradle wrapper to a compatible version and warn about RN/Kotlin/CI impact — name the exact version jump and its risk first.

7. **Match project conventions.**
   Groovy `build.gradle` vs Kotlin `.kts`; `packaging {}` (newer AGP) vs `packagingOptions {}` (older). Edit version catalogs (`libs.versions.toml`) in place if used.

---

## Files To Read Before Editing

```
android/build.gradle
android/app/build.gradle
android/gradle.properties
android/settings.gradle
android/app/src/main/AndroidManifest.xml
gradle/wrapper/gradle-wrapper.properties
package.json
yarn.lock | package-lock.json
```

---

## Decision Order (Always)

```
1. Confirm RN project + detect AGP / Gradle / NDK / compileSdk / targetSdk + native deps + flavors/signing
2. Is the app affected? (ships .so for arm64-v8a/x86_64?) If no native libs → unaffected, stop.
3. AGP < 8.5.1   → upgrade AGP (+ compatible Gradle wrapper)   [highest priority, warn first]
4. Compiling C/C++ with NDK ≤ r27 → upgrade to r28+, else add -Wl,-z,max-page-size=16384 / common-page-size=16384
5. Ensure targetSdk/compileSdk ≥ 35
6. Set jniLibs { useLegacyPackaging = false }   (match project DSL)
7. Audit & bump native dependencies that ship misaligned .so (with evidence)
8. Build: ./gradlew clean → assembleRelease → bundleRelease
9. VALIDATE (mandatory): zipalign -c -P 16 + bundletool PAGE_ALIGNMENT_16K + getconf PAGE_SIZE=16384
10. Report using SKILL.md Output Format (Summary, Files Changed, Compatibility Status,
    Validation Commands Run, Remaining Risks, Next Steps)
```

---

## Tool / Environment Specific Guidance

- **Claude Code:** Run builds + validation via Bash. Use plan-first (EnterPlanMode) for toolchain upgrades. Read files with Read/Grep before editing.
- **Cursor / Windsurf / Antigravity / Cline:** Open and read all files in "Files To Read" before proposing edits. Present a diff plus the validation commands in the same response.
- **Agents without shell access:** Produce exact edits + copy-paste build/validation commands, and mark the result "needs user verification."

---

## Hard Rules (Do Not Violate)

- Do **not** claim 16KB support from a successful build alone.
- Do **not** add fake/unsupported manifest flags or unrelated settings (`android:max_aspect`).
- Do **not** claim a dependency is compatible without evidence; do **not** ignore `.so` files.
- Do **not** blindly upgrade RN / Gradle / AGP / Kotlin / NDK — name the jump and risk; check wrapper compatibility on AGP changes.
- Do **not** remove working code without explaining why and offering a safer alternative.
- Do **not** break build variants, flavors, signing, or CI/CD.
- Do **not** change package name, version code, signing config, or keystore unless explicitly requested.
- Do **proceed** with documented best-practice assumptions when info is sufficient; ask only blocking questions.

---

## Definition of Done

Complete only when:
- Release **APK and AAB** both build, **and**
- `zipalign -c -P 16` passes, `bundletool` shows `PAGE_ALIGNMENT_16K`, and a 16KB target reports `getconf PAGE_SIZE = 16384` (or unknowns are explicitly flagged), **and**
- The report includes Summary, Files Changed, Compatibility Status, Validation Commands Run, Remaining Risks, and Next Steps — and is client-ready.

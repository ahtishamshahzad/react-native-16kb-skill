# React Native Android — 16KB Page Size Support (AI Skill)

A reusable AI coding skill that helps any agent **audit, implement, and validate** Android 16KB memory page size support in a **React Native Android** project — the requirement Google Play enforces for apps targeting Android 15+ (API 35) on 64-bit devices.

It prioritizes the **real** compliance mechanism (native `.so` libraries aligned to 16KB) over cosmetic manifest flags, and **requires verification** (`zipalign` / `bundletool` / 16KB emulator) before claiming success.

## Contents

```
android-16kb-page-size-support/
├── SKILL.md                          # The skill (purpose, steps, rules, checklist, examples)
├── AGENTS.md                         # How agents should behave when this skill is active
├── README.md                         # This file
├── install.sh                        # Installs the skill globally for Claude Code
├── .cursor/rules/android-16kb.mdc    # Cursor rule adapter
├── .windsurfrules                    # Windsurf rules adapter
├── scripts/
│   └── check_elf_alignment.sh        # Offline 16KB .so alignment verifier
└── references/
    └── dependency-matrix.md          # RN native-dependency 16KB compatibility reference
```

## Install / use per tool

### Claude Code (global)
```bash
bash install.sh
```
This copies the skill to `~/.claude/skills/android-16kb-page-size-support/`. Claude Code then auto-discovers it by name/description. Use project-level install instead by copying the folder into `<project>/.claude/skills/`.

### Cursor
Copy `.cursor/rules/android-16kb.mdc` into your project's `.cursor/rules/` directory. Cursor applies it when you touch `android/**` or Gradle files.

### Windsurf
Copy `.windsurfrules` to your project root, or paste its contents into Windsurf's workspace/global rules.

### Cline / Antigravity / other agents
Place `AGENTS.md` (and ideally this whole folder) at the project root. These tools read `AGENTS.md` as their behavior contract. Any agent can also just be told: *"follow SKILL.md in this folder."*

## Quick verification (no agent needed)
```bash
# after a release build:
bash scripts/check_elf_alignment.sh android/app/build/outputs/apk/release/app-release.apk
zipalign -c -P 16 -v 4 android/app/build/outputs/apk/release/app-release.apk
bundletool dump config --bundle=android/app/build/outputs/bundle/release/app-release.aab | grep -i alignment
adb shell getconf PAGE_SIZE   # 16384 on a 16KB target
```

## License
MIT (see `LICENSE` if present, or add one before publishing).

# React Native Android — 16KB Page Size Support (AI Skill)

A reusable AI coding skill that helps any agent **audit, implement, and validate** Android 16KB memory page size support in a **React Native Android** project — the requirement Google Play enforces for apps targeting Android 15+ (API 35) on 64-bit devices.

It prioritizes the **real** compliance mechanism (native `.so` libraries aligned to 16KB) over cosmetic manifest flags, and **requires verification** (`zipalign` / `bundletool` / 16KB emulator) before claiming success.

> **Repo:** https://github.com/ahtishamshahzad/react-native-16kb-skill
> **Compatible agents:** Claude Code, Cursor, Windsurf, Antigravity, Cline, Codex, Gemini CLI, GitHub Copilot, OpenCode, and any agent that reads `SKILL.md` / `AGENTS.md`.

---

## Quick install (recommended) — `skills` CLI

The fastest way. Works for 70+ agents (Claude Code, Cursor, Windsurf, Antigravity, Codex, Gemini CLI, Copilot, …). Run this in your project root:

```bash
npx skills add ahtishamshahzad/react-native-16kb-skill
```

This clones the skill and installs it into the right place for every agent it detects (e.g. `./.agents/skills/…`, symlinked into Claude Code / Windsurf / Devin). No manual copying needed.

Other useful CLI commands:

```bash
npx skills list      # see installed skills
npx skills find       # search the skills.sh directory interactively
npx skills update     # update installed skills
npx skills remove android-16kb-page-size-support   # uninstall
```

> ⚠️ Skills run with full agent permissions — review `SKILL.md` before use.

---

## Manual install — clone the repo

If you prefer to clone and wire it up yourself:

```bash
# 1. Clone
git clone https://github.com/ahtishamshahzad/react-native-16kb-skill.git
cd react-native-16kb-skill

# 2a. Install globally for Claude Code (auto-discovered on next start)
bash install.sh
#     → copies to ~/.claude/skills/android-16kb-page-size-support/

# 2b. OR install for one project only (Claude Code)
mkdir -p /path/to/your-rn-app/.claude/skills
cp -R . /path/to/your-rn-app/.claude/skills/android-16kb-page-size-support
```

---

## Per-tool setup (manual, if not using the CLI)

### Claude Code
```bash
bash install.sh
```
Copies the skill to `~/.claude/skills/android-16kb-page-size-support/`; Claude Code auto-discovers it by `name`/`description`. For project scope, copy the folder into `<project>/.claude/skills/` instead.

### Cursor
Copy `.cursor/rules/android-16kb.mdc` into your project's `.cursor/rules/` directory. Cursor applies it automatically when you touch `android/**` or Gradle files.

### Windsurf
Copy `.windsurfrules` to your project root, or paste its contents into Windsurf's workspace/global rules.

### Cline / Antigravity / other agents
Place `AGENTS.md` (ideally the whole folder) at the project root — these tools read `AGENTS.md` as their behavior contract. Any agent can also simply be told: *"follow SKILL.md in this folder."*

---

## Contents

```
react-native-16kb-skill/
├── SKILL.md                          # The skill (purpose, steps, rules, checklist, examples)
├── AGENTS.md                         # How agents should behave when this skill is active
├── README.md                         # This file
├── LICENSE                           # MIT
├── install.sh                        # Installs the skill globally for Claude Code
├── .cursor/rules/android-16kb.mdc    # Cursor rule adapter
├── .windsurfrules                    # Windsurf rules adapter
├── scripts/
│   └── check_elf_alignment.sh        # Offline 16KB .so alignment verifier
└── references/
    └── dependency-matrix.md          # RN native-dependency 16KB compatibility reference
```

---

## Quick verification (no agent needed)

After a release build, prove 16KB compliance yourself:

```bash
# offline .so alignment check (bundled script)
bash scripts/check_elf_alignment.sh android/app/build/outputs/apk/release/app-release.apk

# APK alignment
zipalign -c -P 16 -v 4 android/app/build/outputs/apk/release/app-release.apk

# AAB alignment (look for PAGE_ALIGNMENT_16K)
bundletool dump config --bundle=android/app/build/outputs/bundle/release/app-release.aab | grep -i alignment

# 16KB device/emulator check
adb shell getconf PAGE_SIZE   # expect: 16384
```

---

## What this skill does (in short)

1. Audits an RN Android project (AGP, Gradle wrapper, NDK, SDK, native deps).
2. Determines if the app is affected (does it ship `.so` for arm64-v8a / x86_64?).
3. Applies safe build config (AGP 8.5.1+, NDK r28+, `useLegacyPackaging = false`).
4. Audits native dependencies for 16KB support — with evidence, not assumptions.
5. Builds release APK + AAB.
6. **Validates** with `zipalign` / `bundletool` / `getconf PAGE_SIZE` — never claims success from a passing build alone.
7. Produces a client-ready report.

See `SKILL.md` for the full workflow, rules, and validation checklist.

---

## License

MIT — see [`LICENSE`](./LICENSE).

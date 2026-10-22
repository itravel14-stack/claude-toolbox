# rea — Reverse Engineer Anything ([morluto/rea](https://github.com/morluto/rea))

Installed by `bootstrap.sh rea` as the official npm package `rea-agents@<PIN>`, then
registered with REA's own setup (`rea setup --client claude_code`):

| What | Where | Scope |
|---|---|---|
| CLI `rea` | npm global prefix (`npm config get prefix`) | the machine/container |
| MCP server `rea` | `mcpServers.rea` in `~/.claude.json` (user scope) | every project Claude Code opens |
| Skill `reverse-engineer-anything` | `~/.claude/skills/` | every project Claude Code opens |
| Ghidra 12.1.4 (decompiler) | `~/tools/ghidra_12.1.4_PUBLIC`, recorded as `GHIDRA_INSTALL_DIR` in the `rea` registration | machine/container |

Ghidra comes from the official release zip, checked against the SHA-256 published in its
release notes (`tools/rea/ghidra.env`). It is skipped when there is no JDK 21+ `javac`
(the cloud image has one) or when `REA_GHIDRA=0`. To update: put the new release's URL and
SHA-256 in `ghidra.env`, run `bash bootstrap.sh rea`, bump `toolbox-rev`.

No repo gets REA files. First setup backs up `~/.claude.json` to `~/.claude.json.rea.backup`
and preserves every other MCP server; reruns are no-ops.

## Use it from any repo

Open Claude Code in the repo and ask. The skill decides when REA fits (shipped artifacts:
Electron/ASAR, JS bundles, native/managed binaries, firmware, APKs) and skips it for
ordinary source-repo questions.

- "Use REA to analyze `./dist/app.asar`: entrypoints, preload bridges, IPC channels, with evidence."
- "Reverse engineer how feature X works in this Electron app I own; separate verified findings from guesses."
- "Compare v1.2 and v1.3 of this bundle with REA and list behavioral changes."
- "Use REA with Ghidra to decompile `./bin/tool` and explain how its license check works."
- "Map this app's modules and dependencies with REA, then implement a similar feature here without copying code."

Direct CLI: `rea analyze-javascript-application <dir|app.asar> --format json > evidence.json`

## What works where

| Capability | Cloud container (Linux) | Needs |
|---|---|---|
| JS / Electron static analysis, artifact graph | yes (verified) | procps `ps` (present) |
| Native binaries via Ghidra (ELF, PE/.exe/.dll, Mach-O, raw) | yes (verified: decompiled a test binary) | installed by the toolbox; JDK 21+ |
| Android via JADX | no | `REA_JADX_MCP_JAR` (jadx-headless-mcp 0.7.1) |
| IDA | no | paid IDA license + `REA_IDA_MCP_CONFIG` |
| Hopper / native-macos | no | macOS only |

Only analyze software you own or are authorized to inspect.

## Maintain

```bash
rea --version                                   # installed version
rea doctor --client claude_code --skill --json  # registration + skill health (read-only)
GHIDRA_INSTALL_DIR=~/tools/ghidra_12.1.4_PUBLIC rea doctor --provider ghidra --json   # engine
claude mcp list | grep rea                      # Claude Code sees it
```

Update (deliberate, never automatic): `npm view rea-agents version`, then write the new
version to `tools/rea/PIN`, run `bash bootstrap.sh rea`, restart Claude Code, commit the PIN.
(`rea update` also works on a global install but leaves PIN stale.)

Troubleshoot: tools missing → `rea doctor --client claude_code --skill`, then
`rea setup --client claude_code` and restart Claude Code. Bad config change → restore
`~/.claude.json.rea.backup`.

Remove (keeps other MCP servers, skills, Node): `rea uninstall` (add `--purge-data` to drop
`~/.rea`), then `npm uninstall --global rea-agents`.

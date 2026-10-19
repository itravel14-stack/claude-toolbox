# vimax — ViMax as a global Claude Code capability

One ViMax install, one `vimax` command, one global skill. Every repo on the machine
uses it; no repo contains ViMax code, deps, or keys.

```
~/tools/ViMax/                     official HKUDS/ViMax clone (engine, .venv, node_modules)
  configs/agent.local.yaml         private keys (git-ignored upstream, chmod 600)
  .vimax/  .working_dir/<session>/ sessions + all intermediate artifacts
~/tools/claude-toolbox/tools/vimax/ recipe: tool.sh, wrapper, skill source, PIN
~/.local/bin/vimax                 -> ~/tools/claude-toolbox/tools/vimax/bin/vimax
~/.claude/skills/vimax/SKILL.md    global skill, auto-loaded in every project
<any repo>/public/videos/...       only the exported final MP4 lands in a project
```

Pinned engine: `fd4b72e7731be6e5f88486206d25ea59849b0285` (v1.2.0 + 4 commits, 2026-09-30).
Tests at that commit: 205 Python + 32 Web passed, offline.

## Install

Prereqs: git, [uv](https://docs.astral.sh/uv/), Node ≥ 18, ffmpeg. Python 3.12+ is fetched by uv.

```bash
bash ~/tools/claude-toolbox/bootstrap.sh vimax
```
Re-runnable. It never replaces an existing ViMax checkout or `agent.local.yaml`, backs
up a differing `SKILL.md`, and refuses to clobber a foreign `~/.local/bin/vimax`.
Override paths with `VIMAX_HOME` / `VIMAX_HUB_HOME`.

**Windows:** run in Git Bash (the Bash Claude Code uses on Windows). ViMax's own
launcher is bash; WSL also works but keep ViMax, uv, and Claude Code all on the
same side (don't mix `C:\` Python with WSL Python). If `ln -s` fails the wrapper is
copied instead, which is fine. Restart Claude Code after install so it loads the skill.

## Keys / providers

Edit `~/tools/ViMax/configs/agent.local.yaml` or export env vars (env wins):

| Stage | Env var | Template default (OpenRouter) |
|---|---|---|
| LLM (planning, VLM keyframe selection) | `VIMAX_LLM_API_KEY` | `google/gemini-2.5-flash` |
| Image (keyframes, character refs) | `VIMAX_IMAGE_API_KEY` → falls back to LLM key | `openai/gpt-image-2` |
| Video (one clip per shot) | `VIMAX_VIDEO_API_KEY` → falls back to LLM key | `google/veo-3.1-lite` or `bytedance/seedance-2.0-fast` |
| Embedding + reranker | `VIMAX_EMBEDDING_*`, `VIMAX_RERANKER_*` | Novel2Video only |

One OpenRouter key covers LLM + image + video. Agent-mode video only routes to
`openrouter.ai` or `yunwu.ai` base URLs. Each var also has `_MODEL` and `_BASE_URL`.
`vimax doctor` reports `set`/`MISSING` per stage, never the value.

Cost levers: `image_selection.num_candidates: 1` (template; upstream default 2 doubles
image calls), cap scenes/shots in the prompt, test with ≤3 shots first.

## Use (from any directory)

```bash
vimax doctor                                   # health + key status
vimax agent --yes --new hero-site "Plan only: 15s 16:9 hero video of a desert modern home at golden hour. Max 3 shots. Don't render."
vimax status                                   # sessions; * = active
vimax status <id>                              # artifact checklist
vimax agent --yes --session <id> "Render the video now."
vimax export <id> "$(git rev-parse --show-toplevel)/public/videos" hero-site-v1
vimax tui            # official terminal UI
vimax web            # official Web UI -> http://127.0.0.1:4173
```
`--yes` is required on every `agent` call: it is the cost-approval switch.
`export` refuses to overwrite and prints duration/resolution/codec via ffprobe.

In Claude Code just ask ("make a hero video for this site"); the `vimax` skill drives
the steps above, stops for cost approval, and exports into the right folder
(`public/videos/` for web frameworks, `assets/generated/` otherwise, briefs in
`docs/video-production/`).

Direct pipelines (`main_idea2video.py`, `main_script2video.py`) also exist upstream but
read inline-key YAMLs in tracked `configs/*.yaml` with hard-coded prompts; don't put keys
there. If you need them, copy to `configs/<name>.local.yaml` (git-ignored pattern).

## Update / rollback

```bash
vimax update-check   # git fetch + list new upstream commits; changes nothing
vimax pin            # record current commit as known-good
# apply manually (command printed by update-check), then:
vimax test           # offline suite
vimax rollback       # back to PIN if anything breaks
```
Nothing auto-updates.

## Remove

```bash
rm ~/.local/bin/vimax
rm -r ~/.claude/skills/vimax; rm -r ~/tools/claude-toolbox/tools/vimax   # then commit the toolbox
rm -r ~/tools/ViMax          # also deletes keys + all sessions/renders; export first
```

## GitHub Actions (optional, unverified)

`extras/vimax-render.example.yml`: manual-dispatch job that clones the pinned
ViMax, runs one headless agent turn with `OPENROUTER_API_KEY` from repo secrets, and
uploads `final_video.mp4` as a workflow artifact (nothing committed). Not installed in
any repo. Not run: whether one `--once` turn plans *and* renders depends on the agent
and prompt; long renders may hit the 120-min timeout.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `vimax: command not found` | add `~/.local/bin` to PATH |
| `ViMax not found at …` | set `VIMAX_HOME` or run bootstrap.sh vimax |
| `… api_key is required …` | fill keys (above) |
| `Unsupported video base_url` | use an openrouter.ai / yunwu.ai base URL |
| `ui/web dependencies are missing` | `cd ~/tools/ViMax/ui && npm install` (or `web`) |
| final assembly error | install ffmpeg |
| skill not offered in Claude Code | restart Claude Code; check `~/.claude/skills/vimax/SKILL.md` |


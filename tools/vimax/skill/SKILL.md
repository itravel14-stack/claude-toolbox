---
name: vimax
description: Generate AI videos (idea-to-video, script-to-video, novel-to-video) with the shared ViMax engine installed at ~/tools/ViMax. Use when the user asks for a hero video, promo/ad, explainer, product demo, social clip, real estate walkthrough, short film, storyboard, or shot list, from any repository. Covers health checks, provider keys, cost approval, rendering, and exporting the MP4 into the current project.
---

# ViMax — shared video engine

ViMax (HKUDS/ViMax) is one central install, never copied into projects.
Engine: `${VIMAX_HOME:-~/tools/ViMax}`. Wrapper: `vimax` (from `~/tools/claude-toolbox/tools/vimax/bin/`).
The wrapper always runs ViMax from its own root, so it works from any repo.

## 1. Decide if ViMax fits
- Use it for AI-generated narrative/visual video from text (and optional reference images).
- Do NOT use it for screen recordings, editing existing footage, code-rendered motion
  (Remotion, CSS/Lottie), or a still image. Say so and suggest the better tool.
- Planning only (story, script, storyboard, shot list) still uses paid LLM calls but no
  image/video spend. Rendering is where the cost is.

## 2. Health check (always first)
```bash
vimax doctor
```
`vimax: command not found` → `bash ~/tools/claude-toolbox/bootstrap.sh vimax`
(cloud sessions run bootstrap from the environment setup script).
All lines PASS + keys "set" → continue. If keys show MISSING, stop and tell the user
which ones (see §6). Never print, cat, or echo `configs/agent.local.yaml` or any key.

## 3. Build the brief (ask only for what is missing)
Capture: purpose + where it will be used, duration / scene + shot cap, aspect ratio
(16:9 web hero, 9:16 social), style, subjects/characters, must-show items, audio
needs, references (image paths). Write it to `<project>/docs/video-production/<slug>-brief.md`.

Workflow choice:
| Input | ViMax workflow |
|---|---|
| short concept / idea | Idea2Video |
| finished screenplay with dialogue | Script2Video |
| long fiction / chapters | Novel2Video (needs embedding + reranker keys) |

## 4. Cost gate (mandatory)
Before any `vimax agent` call: state provider + models from `vimax doctor`, number of
scenes × shots, keyframe candidates (`image_selection.num_candidates`), and that each
shot is one paid video clip. Give a range only when pricing is known; otherwise say
the cost is unknown. Get explicit approval. Never loop retries on a failed render —
report and ask. Start new videos with a ≤3 shot test unless the user says otherwise.

## 5. Run
Headless (preferred from Claude Code), one turn per call:
```bash
vimax agent --yes --new "<project-slug>" "Plan only: <brief>. Idea2Video, max 3 shots, 16:9. Do not render yet."
vimax status                      # find the session id (* = active)
vimax status <id>                 # artifact checklist: story/script/storyboard/final_video
vimax agent --yes --session <id> "Revise: <change>"
vimax agent --yes --session <id> "Render the video now."   # only after cost approval
```
Interactive alternatives the user runs themselves: `vimax tui` (terminal) or
`vimax web` → http://127.0.0.1:4173 (projects, uploads, storyboard + render previews).
Renders can take many minutes; run long `vimax agent` calls in the background and
read progress lines (`· tool: … video_status`). Artifacts live in
`~/tools/ViMax/.working_dir/<id>/{idea2video,script2video,novel2video}/`.

## 6. Providers and secrets
Config: `~/tools/ViMax/configs/agent.local.yaml` (git-ignored). Env vars override it:
`VIMAX_LLM_API_KEY`, `VIMAX_IMAGE_API_KEY`, `VIMAX_VIDEO_API_KEY` (+ `_MODEL`, `_BASE_URL`).
Image and video fall back to the LLM key. Agent-mode video only routes to
`openrouter.ai` or `yunwu.ai` base URLs; one OpenRouter key covers all three stages.
Never write keys into a project, a skill, docs, commits, or chat. Never switch
provider/model silently — that changes cost.

## 7. Deliver into the project
1. Find the project root: `git rev-parse --show-toplevel`.
2. Pick the destination by framework: static/Vite/Next → `public/videos/`;
   other apps → `assets/generated/`; planning docs → `docs/video-production/`.
3. Export (refuses to overwrite):
   ```bash
   vimax export <id> "$(git rev-parse --show-toplevel)/public/videos" hero-<slug>-v1
   ```
4. Check the ffprobe line (duration, resolution, codec). Flag files > 10 MB for web
   use (suggest `ffmpeg -crf 28` re-encode) and > 50 MB for git (suggest LFS/CDN).
5. Never copy `.working_dir/` intermediates or config into the project.

## 8. Report
Session id, workflow, exported path, size/duration/resolution, models used, and what
remains. Only say "rendered" when `vimax status <id>` shows `final_video.mp4` present
and the export succeeded. A plan is not a video.

## Troubleshooting
| Symptom | Fix |
|---|---|
| `ViMax not found` | `export VIMAX_HOME=<path>` or `bash ~/tools/claude-toolbox/bootstrap.sh vimax` |
| `... api_key is required` | key missing — §6 |
| `Unsupported video base_url` | video.base_url must be openrouter.ai or yunwu.ai |
| `ui/web dependencies are missing` | `cd ~/tools/ViMax/ui && npm install` (or `web`) |
| import errors after update | `cd ~/tools/ViMax && uv sync`, then `vimax test` |
| bad output after upgrade | `vimax rollback` |
| final assembly fails | install ffmpeg |

Updates: `vimax update-check` (read-only). Upgrade steps are printed there; run
`vimax pin` first so `vimax rollback` can restore the last good commit.
Full guide: `~/tools/claude-toolbox/tools/vimax/README.md`.

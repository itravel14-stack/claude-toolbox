---
name: openmontage
description: Produce finished AI videos (explainers, trailers, ads, shorts, documentaries, talking heads, podcast clips, localization/dubs, screen demos, character animation) with the central OpenMontage install at ~/tools/openmontage, from ANY repository. Use whenever the user asks to make, edit, render, or storyboard a video, mentions OpenMontage, Backlot, Remotion, or HyperFrames productions, or wants a production's MP4 delivered into the current project.
---

# OpenMontage (central install, used from any repo)

One install lives at `~/tools/openmontage` (pinned in claude-toolbox/tools/openmontage/PIN).
Never copy OpenMontage into the current repository. Its own instructions are the
authority for production work:

1. Read `~/tools/openmontage/AGENT_GUIDE.md` (mandatory — routing rules) and
   `~/tools/openmontage/PROJECT_CONTEXT.md` before acting on a video request.
2. Run every OpenMontage command from inside the install: `cd ~/tools/openmontage`
   (paths like `pipeline_defs/`, `skills/`, `.agents/skills/` are relative to it), using its
   venv: `.venv/bin/python` (Windows: `.venv/Scripts/python.exe`).
3. Every production writes to `~/tools/openmontage/projects/<project-id>/` (or
   `$OPENMONTAGE_PROJECTS_DIR`). Never write production assets into the caller repo.
4. When the video is done, deliver it to the repo the user is working in:
   `openmontage export <project-id> [dest]` (default `./media/openmontage/<id>/`).
   Files over 50 MB: Git LFS or external storage, never plain git
   (claude-toolbox/docs/MEDIA-POLICY.md). Ask before committing renders.

## Commands (`openmontage` is on PATH, works from any directory)

| Command | What it does |
|---|---|
| `openmontage preflight` | capability menu: which tools/providers the current keys unlock |
| `openmontage pipelines` | list pipelines (`pipeline_defs/*.yaml`) |
| `openmontage backlot [id]` | open the Backlot living storyboard (library or one production) |
| `openmontage serve [port]` | Backlot in the foreground on 127.0.0.1 (default 4750) |
| `openmontage projects` | productions on disk, newest first |
| `openmontage demo [name]` | zero-key Remotion demo render (lists demos with no name) |
| `openmontage test` | official pytest suite |
| `openmontage export <id> [dir]` | copy final renders into the current project |
| `openmontage claude` | start Claude Code inside the install |

## Keys

API keys live only in `~/tools/openmontage/.env` (git-ignored, chmod 600) or environment
variables — never in any repository. Zero keys still gives Remotion/HyperFrames
rendering, Piper TTS, FFmpeg, and free stock sources. `openmontage preflight` shows what
each added key unlocks. Cost-incurring providers need the user's approval
(OpenMontage's gates enforce this).

## Cloud sessions

The toolbox setup script installs this for every cloud session. Remotion's own Chrome
download is blocked there, so the toolbox points Remotion at the pre-installed headless
shell (no action needed). Backlot is local-only (127.0.0.1); in the cloud, report its
port with the preview-port tool or screenshot it with Playwright.

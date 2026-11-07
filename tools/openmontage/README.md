# openmontage

[calesthio/OpenMontage](https://github.com/calesthio/OpenMontage) — open-source agentic video
production: 13 pipelines, 150+ tools, Remotion + HyperFrames renderers, Backlot storyboard.

- **Install:** `bash ~/tools/claude-toolbox/bootstrap.sh openmontage` → clones the pinned commit
  to `~/tools/openmontage`, runs the official `make setup` (venv, `requirements.txt`, Remotion
  `npm install`, Piper TTS, HyperFrames npx cache, `.env` from `.env.example`).
  Windows without `make`: run the README's PowerShell one-liner inside `~/tools/openmontage`,
  then re-run bootstrap (it keeps the existing `.venv`).
- **Use from any repo:** global skill `openmontage` + the `openmontage` command (see `skill/SKILL.md`).
- **Keys:** `~/tools/openmontage/.env` only.
- **Productions:** `~/tools/openmontage/projects/` (git-ignored upstream). Back them up with
  `pc/backup-all.sh --openmontage` (plans/scripts always; renders optional).

## Verified (2026-11-07, Linux cloud container, pin in `PIN`)

| Check | Result |
|---|---|
| `make setup` | ok (Python 3.10 venv via uv, Remotion 4.0.484, piper-tts 1.8.0, HyperFrames 0.9.19) |
| `pytest tests/` | 2227 passed, 12 skipped, 3 xfailed |
| `make preflight` | 26 capabilities, 37/151 tools available with zero keys |
| `make hyperframes-doctor` | OK (whisper-cpp/Kokoro/MusicGen optional, not installed) |
| `render_demo.py world-in-numbers` | 1920×1080 h264+aac, 23 s |
| Backlot `serve` + board | HTTP 200, library + live board render |
| Skill from another directory | `openmontage pipelines/preflight/export` ok from `/tmp` project |

Known upstream issue: `scripts/backlot_simulate_run.py` stops at the `script` stage
(`PREREQUISITE VIOLATION ... missing: ['proposal']`); the board still renders the partial run.

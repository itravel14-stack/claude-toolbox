# moneyprinterturbo — [harry0703/MoneyPrinterTurbo](https://github.com/harry0703/MoneyPrinterTurbo)

Topic or script -> finished short video (LLM script, stock footage, TTS voice, subtitles, music).

| What | Where |
|---|---|
| Source + `uv` env (pinned in `PIN`) | `~/MoneyPrinterTurbo` (override with `MPT_HOME`) |
| API keys | `~/MoneyPrinterTurbo/config.toml` (git-ignored, mode 600) or `MPT_*` env vars |
| Official skill `moneyprinterturbo-video` + `mpt_agent.py` | `~/.claude/skills/moneyprinterturbo-video` |

`~/MoneyPrinterTurbo` is the root the official skill reuses, so it never re-downloads the project.

## Use it from any repo

Ask Claude Code: "Make a 30-second English video about how AI is changing everyday life."
The skill runs the helper, asks once for any missing keys, and returns the MP4 path.

Keys (cloud: put them in the environment's variables, never in a repo):
`MPT_LLM_PROVIDER` + `MPT_LLM_API_KEY` (e.g. `openai`, `deepseek`, `gemini`; `oneapi` also needs
`MPT_LLM_BASE_URL`, `MPT_LLM_MODEL_NAME`) and `MPT_PEXELS_API_KEY` (free: pexels.com/api).

Direct CLI: `cd ~/MoneyPrinterTurbo && uv run python cli.py --help`

## Network (cloud environments)

Generation calls the LLM host, `speech.platform.bing.com` (free Edge TTS), `api.pexels.com`
and `videos.pexels.com`. A Limited environment must allow those hosts.

## Maintain

Update: `git -C ~/MoneyPrinterTurbo fetch && git -C ~/MoneyPrinterTurbo log --oneline HEAD..origin/main`,
review, merge, `bash bootstrap.sh moneyprinterturbo`, write the commit to `PIN`, bump `toolbox-rev`.
Remove: delete `~/MoneyPrinterTurbo` (back up `config.toml`) and `~/.claude/skills/moneyprinterturbo-video`.

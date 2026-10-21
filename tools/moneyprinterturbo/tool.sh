# MoneyPrinterTurbo (harry0703) — topic -> finished short video. Sourced by bootstrap.sh.
# Installed at ~/MoneyPrinterTurbo, the root the official agent skill reuses, so the
# upstream skill (docs/skill) works unchanged. install() runs inside the clone (DEST).
REPO=https://github.com/harry0703/MoneyPrinterTurbo.git
DEST="${MPT_HOME:-$HOME/MoneyPrinterTurbo}"

install() {
  command -v uv >/dev/null || { echo "  missing prerequisite: uv"; return 1; }
  uv sync --frozen --python 3.11 --quiet
  # config.toml holds API keys: never committed (upstream .gitignore), never overwritten.
  [[ -f config.toml ]] || { cp config.example.toml config.toml; chmod 600 config.toml; echo "  config: created config.toml"; }
  git check-ignore -q config.toml || { echo "  config.toml is NOT git-ignored"; return 1; }
  # Official skill + helper, copied from the pinned checkout. Upstream lists only
  # macOS/Windows; the toolbox note records that this Linux install is verified.
  local dst="$HOME/.claude/skills/moneyprinterturbo-video"
  mkdir -p "$dst"
  cp docs/skill/SKILL.md docs/skill/mpt_agent.py "$dst/"
  cat >> "$dst/SKILL.md" <<'NOTE'

## Toolbox note (claude-toolbox)

Pre-installed by claude-toolbox at `~/MoneyPrinterTurbo` (dependencies already synced), and
verified on Linux, including Claude Code cloud containers: the Linux path is the same `uv`
command above. API keys come from `config.toml` there or the `MPT_*` environment variables.
NOTE
  echo "  skill: $dst"
}

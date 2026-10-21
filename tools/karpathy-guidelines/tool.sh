# Karpathy guidelines (multica-ai/andrej-karpathy-skills) — one Markdown skill. Sourced by bootstrap.sh.
# Copies the upstream skill as-is to ~/.claude/skills/karpathy-guidelines (every project).
REPO=https://github.com/multica-ai/andrej-karpathy-skills.git

install() {
  local dst="$HOME/.claude/skills/karpathy-guidelines"
  mkdir -p "$dst"
  cp -R skills/karpathy-guidelines/. "$dst/"
}

# REA (morluto/rea) — reverse engineering MCP server + skill. Sourced by bootstrap.sh.
# Installed from npm, not cloned: no REPO, so no source copy under ~/tools.
# PIN here is the npm version of rea-agents (not a commit).
#   global CLI  -> `npm install --global rea-agents@$PIN`  (puts `rea` on PATH)
#   Claude Code -> `rea setup --client claude_code`: user-scope mcpServers.rea in ~/.claude.json
#                  + official skill ~/.claude/skills/reverse-engineer-anything (every project)

install() {
  node -e 'const [a,b]=process.versions.node.split(".").map(Number);
    process.exit((a===22&&b>=19)||(a===24&&b>=11)||a>=26 ? 0 : 1)' \
    || { echo "  missing prerequisite: Node.js ^22.19 || ^24.11 || >=26 (have $(node -v 2>/dev/null || echo none))"; return 1; }
  [[ "$(uname -s)" == Linux ]] && ! command -v ps >/dev/null && echo "  warning: procps 'ps' missing (needed by JS/Electron, Ghidra, JADX workflows)"
  if [[ "$(rea --version 2>/dev/null)" != "$PIN" ]]; then
    npm install --global --no-fund --no-audit "rea-agents@$PIN" >/dev/null
  fi
  echo "  cli: rea $(rea --version)"
  # Additive and idempotent: backs up ~/.claude.json once, preserves other servers, no-op when aligned.
  rea setup --client claude_code --yes --json >/dev/null 2>&1 || { echo "  rea setup failed; run: rea setup --client claude_code"; return 1; }
  rea doctor --client claude_code --skill --json >/dev/null 2>&1 \
    && echo "  doctor: claude_code registration + skill OK" \
    || { echo "  doctor failed; run: rea doctor --client claude_code --skill"; return 1; }
}

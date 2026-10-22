# REA (morluto/rea) — reverse engineering MCP server + skill. Sourced by bootstrap.sh.
# Installed from npm, not cloned: no REPO, so no source copy under ~/tools.
# PIN here is the npm version of rea-agents (not a commit).
#   global CLI  -> `npm install --global rea-agents@$PIN`  (puts `rea` on PATH)
#   Claude Code -> `rea setup --client claude_code`: user-scope mcpServers.rea in ~/.claude.json
#                  + official skill ~/.claude/skills/reverse-engineer-anything (every project)
#   Ghidra      -> verified release in ~/tools/ghidra_<ver>_PUBLIC (needs JDK 21+); setup records
#                  GHIDRA_INSTALL_DIR/JAVA_HOME in the registration. REA_GHIDRA=0 skips it.

install_ghidra() {
  # shellcheck source=/dev/null
  source "$TOOL_DIR/ghidra.env"
  local dir="$TOOLS_HOME/ghidra_${GHIDRA_VERSION}_PUBLIC"
  if [[ ! -x "$dir/support/analyzeHeadless" ]]; then
    local jv; jv="$(javac -version 2>&1 | sed -n 's/^javac \([0-9]*\).*/\1/p')"
    [[ "${jv:-0}" -ge 21 ]] || { echo "  ghidra: skipped (needs JDK 21+ with javac)"; return 0; }
    command -v unzip >/dev/null || { echo "  ghidra: skipped (unzip missing)"; return 0; }
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/ghidra.zip" "$GHIDRA_URL" \
      && echo "$GHIDRA_SHA256  $tmp/ghidra.zip" | sha256sum -c --quiet - \
      && unzip -q "$tmp/ghidra.zip" -d "$TOOLS_HOME" \
      || { rm -rf "$tmp"; echo "  ghidra: download/verify failed"; return 1; }
    rm -rf "$tmp"
  fi
  export GHIDRA_INSTALL_DIR="$dir"
  echo "  ghidra: $GHIDRA_VERSION at $dir"
}

install() {
  node -e 'const [a,b]=process.versions.node.split(".").map(Number);
    process.exit((a===22&&b>=19)||(a===24&&b>=11)||a>=26 ? 0 : 1)' \
    || { echo "  missing prerequisite: Node.js ^22.19 || ^24.11 || >=26 (have $(node -v 2>/dev/null || echo none))"; return 1; }
  [[ "$(uname -s)" == Linux ]] && ! command -v ps >/dev/null && echo "  warning: procps 'ps' missing (needed by JS/Electron, Ghidra, JADX workflows)"
  if [[ "$(rea --version 2>/dev/null)" != "$PIN" ]]; then
    npm install --global --no-fund --no-audit "rea-agents@$PIN" >/dev/null
  fi
  echo "  cli: rea $(rea --version)"
  [[ "${REA_GHIDRA:-1}" == 0 ]] || install_ghidra || return 1
  # Additive and idempotent: backs up ~/.claude.json once, preserves other servers, no-op when aligned.
  rea setup --client claude_code --yes --json >/dev/null 2>&1 || { echo "  rea setup failed; run: rea setup --client claude_code"; return 1; }
  local scope=(--client claude_code --skill); [[ -n "${GHIDRA_INSTALL_DIR:-}" ]] && scope+=(--provider ghidra)
  rea doctor "${scope[@]}" --json >/dev/null 2>&1 \
    && echo "  doctor: ${scope[*]} OK" \
    || { echo "  doctor failed; run: rea doctor ${scope[*]}"; return 1; }
}

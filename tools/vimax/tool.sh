# ViMax (HKUDS) — agentic AI video generation. Sourced by bootstrap.sh.
# Available here: NAME, PIN (from ./PIN), TOOL_DIR, DEST (clone path). install() runs in DEST.
REPO=https://github.com/HKUDS/ViMax.git
DEST="${VIMAX_HOME:-$TOOLS_HOME/ViMax}"

install() {
  for t in uv node npm; do command -v "$t" >/dev/null || { echo "  missing prerequisite: $t"; return 1; }; done
  command -v ffmpeg >/dev/null || echo "  warning: ffmpeg missing (needed for final assembly)"
  uv sync --quiet
  (cd ui && npm install --silent --no-audit --no-fund)
  (cd web && npm install --silent --no-audit --no-fund)
  if [[ ! -f configs/agent.local.yaml ]]; then
    cp "$TOOL_DIR/agent.local.template.yaml" configs/agent.local.yaml
    chmod 600 configs/agent.local.yaml
    echo "  config: created configs/agent.local.yaml (add keys or set VIMAX_LLM_API_KEY)"
  fi
  git check-ignore -q configs/agent.local.yaml || { echo "  agent.local.yaml is NOT git-ignored"; return 1; }
}

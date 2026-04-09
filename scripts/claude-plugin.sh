#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

find_plugin_root() {
  if [[ -n "${CODEX_PLUGIN_ROOT:-}" ]]; then
    if [[ -f "$CODEX_PLUGIN_ROOT/scripts/claude-companion.mjs" ]]; then
      printf '%s\n' "$CODEX_PLUGIN_ROOT"
      return 0
    fi
    echo "CODEX_PLUGIN_ROOT is set but claude-companion.mjs was not found there" >&2
    return 1
  fi

  local candidate
  for candidate in \
    "$REPO_ROOT/../codex-plugin-claudeagent/plugins/claudeagent" \
    "$REPO_ROOT/plugins/claudeagent"
  do
    if [[ -f "$candidate/scripts/claude-companion.mjs" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  candidate="$(
    find "${HOME}/.codex/plugins" -path '*/scripts/claude-companion.mjs' -print 2>/dev/null \
      | sort \
      | tail -n 1
  )"
  if [[ -n "$candidate" ]]; then
    dirname "$(dirname "$candidate")"
    return 0
  fi

  return 1
}

if ! command -v node >/dev/null 2>&1; then
  echo "node is required to run the Claude plugin wrapper" >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: ./scripts/claude-plugin.sh <setup|task|status|result|cancel> [args...]" >&2
  exit 2
fi

PLUGIN_ROOT=$(find_plugin_root || true)
if [[ -z "$PLUGIN_ROOT" ]]; then
  echo "Claude plugin root not found. Set CODEX_PLUGIN_ROOT to the claudeagent plugin directory." >&2
  exit 1
fi

exec node "$PLUGIN_ROOT/scripts/claude-companion.mjs" "$@"

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/init-campaign-repo.sh <campaign-repo-path> --campaign-id <id> --title <title> --objective <objective> [--force]

The script copies templates/campaign-repo into the target directory and fills
the standard placeholders in campaign.md.
EOF
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 1
fi

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

TARGET_DIR=$1
shift

CAMPAIGN_ID=""
TITLE=""
OBJECTIVE=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --campaign-id)
      CAMPAIGN_ID=${2:-}
      shift 2
      ;;
    --title)
      TITLE=${2:-}
      shift 2
      ;;
    --objective)
      OBJECTIVE=${2:-}
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$CAMPAIGN_ID" || -z "$TITLE" || -z "$OBJECTIVE" ]]; then
  echo "--campaign-id, --title, and --objective are required" >&2
  usage >&2
  exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TEMPLATE_DIR="$REPO_ROOT/templates/campaign-repo"

mkdir -p "$(dirname -- "$TARGET_DIR")"
if [[ -e "$TARGET_DIR" ]]; then
  if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Target path exists and is not a directory: $TARGET_DIR" >&2
    exit 1
  fi
  if [[ "$FORCE" -ne 1 ]] && [[ -n "$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "Target directory already exists and is not empty: $TARGET_DIR" >&2
    echo "Re-run with --force to overwrite it." >&2
    exit 1
  fi
  rm -rf "$TARGET_DIR"
fi

mkdir -p "$TARGET_DIR"
cp -R "$TEMPLATE_DIR"/. "$TARGET_DIR"/

CAMPAIGN_MD="$TARGET_DIR/campaign.md"
python3 - "$CAMPAIGN_MD" "$CAMPAIGN_ID" "$TITLE" "$OBJECTIVE" "$TARGET_DIR" <<'PY'
from pathlib import Path
import sys

campaign_md = Path(sys.argv[1])
campaign_id, title, objective, target_dir = sys.argv[2:6]
text = campaign_md.read_text(encoding="utf-8")
replacements = {
    "__CAMPAIGN_ID__": campaign_id,
    "__CAMPAIGN_TITLE__": title,
    "__CAMPAIGN_OBJECTIVE__": objective,
    "__CAMPAIGN_REPO_PATH__": target_dir,
}
for old, new in replacements.items():
    text = text.replace(old, new)
campaign_md.write_text(text, encoding="utf-8")
PY

printf 'Initialized campaign repo at %s\n' "$TARGET_DIR"

#!/usr/bin/env bash
#
# build-prompt.sh - Generate Ralph prompt from template with variable substitution
#
# Usage:
#   ./build-prompt.sh                    # Output to temp file
#   ./build-prompt.sh --output FILE      # Output to specific file
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/ralph-env.sh"

TEMPLATE="$SCRIPT_DIR/prompt-template.md"

# =============================================================================
# Helper Functions
# =============================================================================

# Print error message to stderr and exit
die() {
  echo "ERROR: $1" >&2
  exit 1
}

# Return value or "N/A" based on condition
# Usage: resolve_or_na "value" "condition_type"
#   condition_type: "file", "dir", or "value" (default)
resolve_or_na() {
  local value="$1"
  local type="${2:-value}"

  case "$type" in
    file)  [[ -f "$value" ]] && echo "$value" || echo "N/A" ;;
    dir)   [[ -d "$value" && -n "$(ls -A "$value" 2>/dev/null)" ]] && echo "$value" || echo "N/A" ;;
    *)     [[ -n "$value" ]] && echo "$value" || echo "N/A" ;;
  esac
}

# =============================================================================
# Argument Parsing
# =============================================================================

parse_output_file() {
  if [[ "${1:-}" == "--output" ]]; then
    local output="${2:-}"
    [[ -n "$output" ]] || die "--output requires a path"
    echo "$output"
  else
    mktemp -t ralph-prompt.XXXXXX
  fi
}

# =============================================================================
# Main
# =============================================================================

[[ -f "$TEMPLATE" ]] || die "prompt template not found at $TEMPLATE"

OUTPUT_FILE="$(parse_output_file "${1:-}" "${2:-}")"
PROMISE="${RALPH_PROMISE:-COMPLETE}"

# Resolve optional paths (set to "N/A" if missing)
RESEARCH_PATH="$(resolve_or_na "$RESEARCH" file)"
DATA_MODEL_PATH="$(resolve_or_na "$DATA_MODEL" file)"
QUICKSTART_PATH="$(resolve_or_na "$QUICKSTART" file)"
CONTRACTS_PATH="$(resolve_or_na "$CONTRACTS_DIR" dir)"
REPO_SLUG_VALUE="$(resolve_or_na "$REPO_SLUG")"
GUARDRAILS_PATH="$(resolve_or_na "$RALPH_GUARDRAILS" file)"

# =============================================================================
# Template Rendering
# =============================================================================

export TEMPLATE OUTPUT_FILE PROMISE
export RESEARCH_PATH DATA_MODEL_PATH QUICKSTART_PATH CONTRACTS_PATH REPO_SLUG_VALUE
export GUARDRAILS_PATH

python - <<'PY'
import os
from pathlib import Path

template_path = Path(os.environ["TEMPLATE"])
output_path = Path(os.environ["OUTPUT_FILE"])
guardrails_path = os.environ["GUARDRAILS_PATH"]

# Load guardrails content if available
guardrails_content = ""
if guardrails_path != "N/A" and Path(guardrails_path).exists():
    guardrails_content = Path(guardrails_path).read_text(encoding="utf-8").strip()
else:
    guardrails_content = "(No guardrails defined yet)"

values = {
    "REPO_ROOT": os.environ["REPO_ROOT"],
    "FEATURE_DIR": os.environ["FEATURE_DIR"],
    "FEATURE_SPEC": os.environ["FEATURE_SPEC"],
    "IMPL_PLAN": os.environ["IMPL_PLAN"],
    "TASKS": os.environ["TASKS"],
    "PROGRESS_FILE": os.environ["PROGRESS_FILE"],
    "RESEARCH": os.environ["RESEARCH_PATH"],
    "DATA_MODEL": os.environ["DATA_MODEL_PATH"],
    "CONTRACTS_DIR": os.environ["CONTRACTS_PATH"],
    "QUICKSTART": os.environ["QUICKSTART_PATH"],
    "REPO_SLUG": os.environ["REPO_SLUG_VALUE"],
    "PROMISE": os.environ["PROMISE"],
    "GUARDRAILS": guardrails_content,
}

content = template_path.read_text(encoding="utf-8")
for key, value in values.items():
    content = content.replace("{{%s}}" % key, value)

output_path.write_text(content, encoding="utf-8")
print(str(output_path))
PY

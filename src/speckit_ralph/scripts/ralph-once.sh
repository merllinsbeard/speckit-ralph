#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/ralph-env.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/agent-commands.sh"

# Parse arguments
AGENT="${RALPH_AGENT:-$DEFAULT_AGENT}"
PROMISE="${RALPH_PROMISE:-COMPLETE}"
ARTIFACT_DIR="${RALPH_ARTIFACT_DIR:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent|-a)
      [[ -n "${2:-}" ]] || { echo "ERROR: --agent requires a value" >&2; exit 1; }
      AGENT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Validate agent
validate_agent "$AGENT" || exit 1

# Setup prompt and output files
if [[ -n "$ARTIFACT_DIR" ]]; then
  mkdir -p "$ARTIFACT_DIR"
  PROMPT_FILE="$ARTIFACT_DIR/prompt.md"
  OUTPUT_FILE="$ARTIFACT_DIR/$(get_agent_output_file "$AGENT")"
  "$SCRIPT_DIR/build-prompt.sh" --output "$PROMPT_FILE"
else
  PROMPT_FILE="$($SCRIPT_DIR/build-prompt.sh)"
  OUTPUT_FILE="$(mktemp -t "ralph-$(get_agent_output_file "$AGENT").XXXXXX")"
fi

# Cleanup temporary files if not keeping artifacts
cleanup() {
  if [[ -z "$ARTIFACT_DIR" ]]; then
    rm -f "$PROMPT_FILE" "$OUTPUT_FILE"
  fi
}

# Get agent command template
AGENT_CMD=$(get_agent_cmd "$AGENT")

# Expand command template with actual values
AGENT_CMD=$(expand_agent_cmd "$AGENT_CMD" \
  prompt="$PROMPT_FILE" \
  output="$OUTPUT_FILE" \
  repo_root="$REPO_ROOT" \
  sandbox="${CODEX_SANDBOX:-workspace-write}" \
  approval_policy="${CODEX_APPROVAL_POLICY:-never}")

# Execute agent command
set +e
if [[ "$AGENT" == "claude" ]]; then
  # Claude outputs to stdout, redirect to output file then display
  eval "$AGENT_CMD" > "$OUTPUT_FILE" 2>&1
  CMD_STATUS=$?
  cat "$OUTPUT_FILE"
else
  # Codex outputs to stdout directly, last message saved to output file
  eval "$AGENT_CMD"
  CMD_STATUS=$?
fi
set -e

# Check for completion promise
if [[ -f "$OUTPUT_FILE" ]] && grep -q "<promise>${PROMISE}</promise>" "$OUTPUT_FILE"; then
  echo ""
  echo "[ralph] promise detected: ${PROMISE}"
  cleanup
  exit 0
fi

cleanup
exit "$CMD_STATUS"

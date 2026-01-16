#!/usr/bin/env bash
#
# Agent command templates for Ralph Wiggum Loop
#
# Each agent has two command templates:
#   - Regular: reads prompt from file/stdin
#   - Interactive: prompt passed as argument
#

# Claude Code CLI
AGENT_CLAUDE_CMD="claude --print --dangerously-skip-permissions --output-format text \"\$(cat {prompt})\""
AGENT_CLAUDE_INTERACTIVE_CMD="claude --dangerously-skip-permissions {prompt}"
AGENT_CLAUDE_OUTPUT_FILE="output.txt"
AGENT_CLAUDE_SLEEP_DEFAULT=2

# Codex CLI
AGENT_CODEX_CMD="codex exec -C \"{repo_root}\" -s \"{sandbox}\" -c \"approval_policy=\\\"{approval_policy}\\\"\" --output-last-message \"{output}\" < \"{prompt}\""
AGENT_CODEX_INTERACTIVE_CMD="codex exec -C \"{repo_root}\" -s \"{sandbox}\" -c \"approval_policy=\\\"{approval_policy}\\\"\" {prompt}"
AGENT_CODEX_OUTPUT_FILE="last-message.txt"
AGENT_CODEX_SANDBOX="${CODEX_SANDBOX:-workspace-write}"
AGENT_CODEX_APPROVAL_POLICY="${CODEX_APPROVAL_POLICY:-never}"
AGENT_CODEX_SLEEP_DEFAULT=1

# Default agent
DEFAULT_AGENT="${RALPH_AGENT:-claude}"

# =============================================================================
# Helper Functions
# =============================================================================

# Get command template for agent
get_agent_cmd() {
  local agent="$1"
  local mode="${2:-regular}"  # regular or interactive

  case "$agent" in
    claude)
      if [[ "$mode" == "interactive" ]]; then
        echo "$AGENT_CLAUDE_INTERACTIVE_CMD"
      else
        echo "$AGENT_CLAUDE_CMD"
      fi
      ;;
    codex)
      if [[ "$mode" == "interactive" ]]; then
        echo "$AGENT_CODEX_INTERACTIVE_CMD"
      else
        echo "$AGENT_CODEX_CMD"
      fi
      ;;
    *)
      echo "ERROR: Unknown agent: $agent" >&2
      return 1
      ;;
  esac
}

# Get output filename for agent
get_agent_output_file() {
  local agent="$1"

  case "$agent" in
    claude) echo "$AGENT_CLAUDE_OUTPUT_FILE" ;;
    codex) echo "$AGENT_CODEX_OUTPUT_FILE" ;;
    *)
      echo "ERROR: Unknown agent: $agent" >&2
      return 1
      ;;
  esac
}

# Get default sleep duration for agent
get_agent_sleep_default() {
  local agent="$1"

  case "$agent" in
    claude) echo "$AGENT_CLAUDE_SLEEP_DEFAULT" ;;
    codex) echo "$AGENT_CODEX_SLEEP_DEFAULT" ;;
    *)
      echo "ERROR: Unknown agent: $agent" >&2
      return 1
      ;;
  esac
}

# Validate agent name
validate_agent() {
  local agent="$1"

  case "$agent" in
    claude|codex)
      return 0
      ;;
    *)
      echo "ERROR: Invalid agent '$agent'. Valid agents: claude, codex" >&2
      return 1
      ;;
  esac
}

# Expand command template with values
expand_agent_cmd() {
  local cmd="$1"
  shift

  # Replace placeholders with actual values
  # Accepts key=value pairs
  local result="$cmd"
  while [[ $# -gt 0 ]]; do
    local key="${1%%=*}"
    local value="${1#*=}"
    result="${result//\{$key\}/$value}"
    shift
  done

  echo "$result"
}

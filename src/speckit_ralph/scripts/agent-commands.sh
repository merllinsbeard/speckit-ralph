#!/usr/bin/env bash
#
# Agent command templates for Ralph Wiggum Loop
#
# Each agent defines: command templates, output filename, and sleep duration
#

# =============================================================================
# Agent Definitions
# =============================================================================

# Claude Code CLI
declare -A AGENT_CLAUDE=(
  [cmd]='claude --print --dangerously-skip-permissions --output-format text "$(cat {prompt})"'
  [interactive_cmd]='claude --dangerously-skip-permissions {prompt}'
  [output_file]='output.txt'
  [sleep_default]=2
)

# Codex CLI
declare -A AGENT_CODEX=(
  [cmd]='codex exec -C "{repo_root}" -s "{sandbox}" -c "approval_policy=\"{approval_policy}\"" --output-last-message "{output}" < "{prompt}"'
  [interactive_cmd]='codex exec -C "{repo_root}" -s "{sandbox}" -c "approval_policy=\"{approval_policy}\"" {prompt}'
  [output_file]='last-message.txt'
  [sleep_default]=1
)

# Droid CLI
declare -A AGENT_DROID=(
  [cmd]='droid exec --skip-permissions-unsafe -f {prompt}'
  [interactive_cmd]='droid --skip-permissions-unsafe {prompt}'
  [output_file]='output.txt'
  [sleep_default]=2
)

# OpenCode CLI
declare -A AGENT_OPENCODE=(
  [cmd]='opencode run "$(cat {prompt})"'
  [interactive_cmd]='opencode --prompt {prompt}'
  [output_file]='output.txt'
  [sleep_default]=2
)

# List of valid agents
VALID_AGENTS="claude codex droid opencode"
DEFAULT_AGENT="${RALPH_AGENT:-}"

# =============================================================================
# Helper Functions
# =============================================================================

# Get agent array reference by name
_get_agent_ref() {
  local agent="$1"
  case "$agent" in
    claude) echo "AGENT_CLAUDE" ;;
    codex) echo "AGENT_CODEX" ;;
    droid) echo "AGENT_DROID" ;;
    opencode) echo "AGENT_OPENCODE" ;;
    *)
      echo "ERROR: Unknown agent: $agent" >&2
      return 1
      ;;
  esac
}

# Get agent property
_get_agent_property() {
  local agent="$1"
  local property="$2"
  local ref
  ref="$(_get_agent_ref "$agent")" || return 1
  local key="${ref}[$property]"
  echo "${!key}"
}

# Validate agent name
validate_agent() {
  local agent="$1"
  for valid in $VALID_AGENTS; do
    [[ "$agent" == "$valid" ]] && return 0
  done
  echo "ERROR: Invalid agent '$agent'. Valid agents: $VALID_AGENTS" >&2
  return 1
}

# Get command template for agent
get_agent_cmd() {
  local agent="$1"
  local mode="${2:-regular}"
  local property="cmd"
  [[ "$mode" == "interactive" ]] && property="interactive_cmd"
  _get_agent_property "$agent" "$property"
}

# Get output filename for agent
get_agent_output_file() {
  _get_agent_property "$1" "output_file"
}

# Get default sleep duration for agent
get_agent_sleep_default() {
  _get_agent_property "$1" "sleep_default"
}

# Expand command template with values (accepts key=value pairs)
expand_agent_cmd() {
  local result="$1"
  shift
  while [[ $# -gt 0 ]]; do
    local key="${1%%=*}"
    local value="${1#*=}"
    result="${result//\{$key\}/$value}"
    shift
  done
  echo "$result"
}

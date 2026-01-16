#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# Path Resolution
# =============================================================================

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH="" cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_SCRIPT="$REPO_ROOT/.specify/scripts/bash/common.sh"

# =============================================================================
# Helper Functions
# =============================================================================

# Validates that a required file exists, exits with helpful message if not
# Arguments:
#   $1 - file path to check
#   $2 - file description for error message
#   $3 - suggestion command to run
require_file() {
  local file_path="$1"
  local description="$2"
  local suggestion="$3"

  if [[ ! -f "$file_path" ]]; then
    echo "ERROR: $description not found at $file_path" >&2
    echo "Run $suggestion first." >&2
    exit 1
  fi
}

# Extracts repository slug (owner/repo) from git remote URL
# Supports both SSH and HTTPS GitHub URLs
# Sets: REPO_REMOTE_URL, REPO_SLUG
extract_repo_slug() {
  REPO_REMOTE_URL=""
  REPO_SLUG=""

  if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return
  fi

  if ! git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1; then
    return
  fi

  REPO_REMOTE_URL="$(git -C "$REPO_ROOT" remote get-url origin)"

  case "$REPO_REMOTE_URL" in
    git@github.com:*)
      REPO_SLUG="${REPO_REMOTE_URL#git@github.com:}"
      REPO_SLUG="${REPO_SLUG%.git}"
      ;;
    https://github.com/*)
      REPO_SLUG="${REPO_REMOTE_URL#https://github.com/}"
      REPO_SLUG="${REPO_SLUG%.git}"
      ;;
  esac
}

# =============================================================================
# Load Common Utilities (SPEC-KIT dependency)
# =============================================================================

# Check for SPEC-KIT setup with detailed guidance
if [[ ! -f "$COMMON_SCRIPT" ]]; then
  echo "" >&2
  echo "ERROR: SPEC-KIT not initialized in this project." >&2
  echo "" >&2
  echo "Ralph requires SPEC-KIT to be set up first. Run these commands:" >&2
  echo "" >&2
  echo "  1. Install SPEC-KIT:" >&2
  echo "     uv tool install specify-cli --from git+https://github.com/github/spec-kit.git" >&2
  echo "" >&2
  echo "  2. Initialize SPEC-KIT in your project:" >&2
  echo "     specify init . --here --ai claude" >&2
  echo "" >&2
  echo "  3. Create your spec with /speckit.specify in Claude Code" >&2
  echo "" >&2
  echo "Then run 'speckit-ralph init' to set up Ralph." >&2
  echo "" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

eval "$(get_feature_paths)"

# =============================================================================
# Spec Directory Override (--spec flag)
# =============================================================================

# If RALPH_SPEC_DIR is set, override the branch-detected paths
if [[ -n "${RALPH_SPEC_DIR:-}" ]]; then
  # Handle relative paths by prepending REPO_ROOT
  if [[ "$RALPH_SPEC_DIR" == /* ]]; then
    FEATURE_DIR="$RALPH_SPEC_DIR"
  else
    FEATURE_DIR="$REPO_ROOT/$RALPH_SPEC_DIR"
  fi

  # Override spec-related paths
  FEATURE_SPEC="$FEATURE_DIR/spec.md"
  IMPL_PLAN="$FEATURE_DIR/plan.md"
  TASKS="$FEATURE_DIR/tasks.md"
  RESEARCH="$FEATURE_DIR/research.md"
  DATA_MODEL="$FEATURE_DIR/data-model.md"
  QUICKSTART="$FEATURE_DIR/quickstart.md"
  CONTRACTS_DIR="$FEATURE_DIR/contracts"

  # Skip branch validation when using explicit spec
  RALPH_SKIP_BRANCH_CHECK=1
fi

# =============================================================================
# Branch Validation
# =============================================================================

if [[ "${RALPH_SKIP_BRANCH_CHECK:-}" != "1" ]]; then
  check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || exit 1
fi

# =============================================================================
# Required Files Validation
# =============================================================================

require_file "$IMPL_PLAN" "plan.md" "/speckit.plan"
require_file "$FEATURE_SPEC" "spec.md" "/speckit.specify"
require_file "$TASKS" "tasks.md" "/speckit.tasks"

# =============================================================================
# Progress File Setup
# =============================================================================

PROGRESS_FILE_DEFAULT="$FEATURE_DIR/progress.txt"
PROGRESS_FILE="${RALPH_PROGRESS_FILE:-$PROGRESS_FILE_DEFAULT}"

if [[ ! -f "$PROGRESS_FILE" ]]; then
  cat <<'HEADER' > "$PROGRESS_FILE"
# Ralph Progress Log
#
# Append entries after each completed task:
# - Task ID and description
# - Decisions and rationale
# - Files changed
# - Tests run and results
# - Blockers/notes
HEADER
fi

# =============================================================================
# Ralph Directory Setup (.speckit-ralph/)
# =============================================================================

RALPH_DIR="${RALPH_DIR:-$REPO_ROOT/.speckit-ralph}"
RALPH_GUARDRAILS="$RALPH_DIR/guardrails.md"
RALPH_ACTIVITY_LOG="$RALPH_DIR/activity.log"
RALPH_ERRORS_LOG="$RALPH_DIR/errors.log"
RALPH_RUNS_DIR="$RALPH_DIR/runs"

# Initialize .speckit-ralph directory and files if they don't exist
init_ralph_dir() {
  mkdir -p "$RALPH_DIR" "$RALPH_RUNS_DIR"

  if [[ ! -f "$RALPH_GUARDRAILS" ]]; then
    cat <<'GUARDRAILS' > "$RALPH_GUARDRAILS"
# Guardrails (Signs)

> Lessons learned from failures. Read before acting.

## Core Signs

### Sign: Read Before Writing
- **Trigger**: Before modifying any file
- **Instruction**: Read the file first
- **Added after**: Core principle

### Sign: Test Before Commit
- **Trigger**: Before committing changes
- **Instruction**: Run required tests and verify outputs
- **Added after**: Core principle

---

## Learned Signs

<!-- Add project-specific signs below -->
GUARDRAILS
  fi

  if [[ ! -f "$RALPH_ACTIVITY_LOG" ]]; then
    cat <<'ACTIVITY' > "$RALPH_ACTIVITY_LOG"
# Activity Log

## Run Summary

## Events
ACTIVITY
  fi

  if [[ ! -f "$RALPH_ERRORS_LOG" ]]; then
    cat <<'ERRORS' > "$RALPH_ERRORS_LOG"
# Error Log

> Failures and repeated issues. Use this to add guardrails.
ERRORS
  fi
}

# Log a timestamped message to a file
# Usage: _log_to "file" "message"
_log_to() {
  local file="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$file"
}

# Log an activity event
log_activity() { _log_to "$RALPH_ACTIVITY_LOG" "$1"; }

# Log an error event
log_error() { _log_to "$RALPH_ERRORS_LOG" "$1"; }

# Append a line to the Run Summary section
# Usage: append_run_summary "2026-01-16 22:00:00 | run=abc | iter=1 | duration=120s"
append_run_summary() {
  local line="$1"
  python3 - "$RALPH_ACTIVITY_LOG" "$line" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
line = sys.argv[2]

if not path.exists():
    path.write_text(f"# Activity Log\n\n## Run Summary\n- {line}\n\n## Events\n")
    sys.exit(0)

text = path.read_text().splitlines()
out = []
inserted = False

for l in text:
    out.append(l)
    if not inserted and l.strip() == "## Run Summary":
        out.append(f"- {line}")
        inserted = True

if not inserted:
    out = [
        "# Activity Log",
        "",
        "## Run Summary",
        f"- {line}",
        "",
        "## Events",
        "",
    ] + text

path.write_text("\n".join(out).rstrip() + "\n")
PY
}

# Initialize on source
init_ralph_dir

# =============================================================================
# Repository Information
# =============================================================================

extract_repo_slug

# =============================================================================
# Export Environment Variables
# =============================================================================

export REPO_ROOT
export CURRENT_BRANCH
export FEATURE_DIR
export FEATURE_SPEC
export IMPL_PLAN
export TASKS
export RESEARCH
export DATA_MODEL
export QUICKSTART
export CONTRACTS_DIR
export PROGRESS_FILE
export REPO_REMOTE_URL
export REPO_SLUG
export RALPH_DIR
export RALPH_GUARDRAILS
export RALPH_ACTIVITY_LOG
export RALPH_ERRORS_LOG
export RALPH_RUNS_DIR

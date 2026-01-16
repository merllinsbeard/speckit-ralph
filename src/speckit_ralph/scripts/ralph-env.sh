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
# Load Common Utilities
# =============================================================================

require_file "$COMMON_SCRIPT" ".specify common script" "speckit setup"

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

eval "$(get_feature_paths)"

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
# Ralph Directory Setup (.ralph/)
# =============================================================================

RALPH_DIR="${RALPH_DIR:-$REPO_ROOT/.ralph}"
RALPH_GUARDRAILS="$RALPH_DIR/guardrails.md"
RALPH_ACTIVITY_LOG="$RALPH_DIR/activity.log"
RALPH_ERRORS_LOG="$RALPH_DIR/errors.log"
RALPH_RUNS_DIR="$RALPH_DIR/runs"

# Initialize .ralph directory and files if they don't exist
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

# Log an activity event with timestamp
# Usage: log_activity "ITERATION 1 start"
log_activity() {
  local message="$1"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] $message" >> "$RALPH_ACTIVITY_LOG"
}

# Log an error event with timestamp
# Usage: log_error "ITERATION 1 failed with status 1"
log_error() {
  local message="$1"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] $message" >> "$RALPH_ERRORS_LOG"
}

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

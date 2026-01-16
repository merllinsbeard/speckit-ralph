#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH="" cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] <iterations>

Options:
  --agent, -a AGENT  Agent to use: claude or codex (default: claude)
  --detach, -d       Run in background (detached via nohup)
  --log PATH         Write stdout/stderr to PATH (detach mode only)
  --pid PATH         Write PID to PATH (detach mode only)
  --help, -h         Show this help
EOF
}

# --- Argument Parsing ---

AGENT=""
DETACH=0
LOG_FILE=""
PID_FILE=""
ITERATIONS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent|-a)
      AGENT="${2:-}"
      if [[ -z "$AGENT" ]]; then
        echo "ERROR: --agent requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --detach|-d)
      DETACH=1
      shift
      ;;
    --log)
      LOG_FILE="${2:-}"
      if [[ -z "$LOG_FILE" ]]; then
        echo "ERROR: --log requires a path" >&2
        exit 1
      fi
      shift 2
      ;;
    --pid)
      PID_FILE="${2:-}"
      if [[ -z "$PID_FILE" ]]; then
        echo "ERROR: --pid requires a path" >&2
        exit 1
      fi
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$ITERATIONS" ]]; then
        ITERATIONS="$1"
        shift
      else
        echo "ERROR: unexpected argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$ITERATIONS" ]]; then
  usage >&2
  exit 1
fi

# --- Detach Mode ---

detach_loop() {
  if ! command -v nohup >/dev/null 2>&1; then
    echo "ERROR: nohup is required for --detach mode" >&2
    exit 1
  fi

  TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  LOG_FILE="${LOG_FILE:-$REPO_ROOT/logs/ralph-${AGENT}-$TIMESTAMP.log}"
  PID_FILE="${PID_FILE:-$REPO_ROOT/logs/ralph-${AGENT}.pid}"

  mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"

  # Re-run without --detach
  local args=("$ITERATIONS")
  [[ -n "$AGENT" ]] && args+=("--agent" "$AGENT")

  nohup "$0" "${args[@]}" >"$LOG_FILE" 2>&1 &
  PID=$!
  echo "$PID" > "$PID_FILE"

  echo "[ralph] detached: pid $PID"
  echo "[ralph] log: $LOG_FILE"
  echo "[ralph] pid file: $PID_FILE"
  exit 0
}

# Must determine agent before detach to use it in log/pid filenames
# shellcheck source=/dev/null
source "$SCRIPT_DIR/agent-commands.sh"

AGENT="${AGENT:-${RALPH_AGENT:-$DEFAULT_AGENT}}"
validate_agent "$AGENT" || exit 1

if [[ "$DETACH" -eq 1 ]]; then
  detach_loop
fi

# Source environment (includes logging functions)
# shellcheck source=ralph-env.sh
source "$SCRIPT_DIR/ralph-env.sh"

# --- Artifact Management ---

PROMISE="${RALPH_PROMISE:-COMPLETE}"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
KEEP_ARTIFACTS="${RALPH_ARTIFACT_DIR:+1}"
ARTIFACT_DIR="${RALPH_ARTIFACT_DIR:-$(mktemp -d -t "ralph-${AGENT}-loop.XXXXXX")}"
mkdir -p "$ARTIFACT_DIR"

# Get agent-specific output filename
OUTPUT_FILENAME="$(get_agent_output_file "$AGENT")"

# Get agent-specific sleep default
SLEEP_DEFAULT="$(get_agent_sleep_default "$AGENT")"

cleanup_artifacts() {
  if [[ -z "$KEEP_ARTIFACTS" ]]; then
    rm -rf "$ARTIFACT_DIR"
  else
    echo "[ralph] artifacts kept at: $ARTIFACT_DIR"
  fi
}

check_promise() {
  local output_file="$ARTIFACT_DIR/$OUTPUT_FILENAME"
  if [[ -f "$output_file" ]] && \
    grep -q "<promise>${PROMISE}</promise>" "$output_file"; then
    echo "[ralph] promise detected: ${PROMISE}"
    cleanup_artifacts
    exit 0
  fi
}

# Capture git HEAD for tracking
git_head() {
  git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo ""
}

# --- Main Iteration Loop ---

log_activity "LOOP START run=$RUN_ID iterations=$ITERATIONS agent=$AGENT"

for ((i=1; i<=ITERATIONS; i++)); do
  echo ""
  echo "========================================"
  echo "[ralph] iteration ${i}/${ITERATIONS} (agent: $AGENT)"
  echo "========================================"

  ITER_START=$(date +%s)
  ITER_START_FMT=$(date '+%Y-%m-%d %H:%M:%S')
  HEAD_BEFORE="$(git_head)"

  log_activity "ITERATION $i start (run=$RUN_ID agent=$AGENT)"

  set +e
  RALPH_ARTIFACT_DIR="$ARTIFACT_DIR" "$SCRIPT_DIR/ralph-once.sh" --agent "$AGENT"
  CMD_STATUS=$?
  set -e

  ITER_END=$(date +%s)
  ITER_DURATION=$((ITER_END - ITER_START))
  HEAD_AFTER="$(git_head)"

  # Log iteration completion
  if [[ "$CMD_STATUS" -ne 0 ]]; then
    log_error "ITERATION $i failed (run=$RUN_ID agent=$AGENT status=$CMD_STATUS)"
    STATUS_LABEL="error"
  else
    STATUS_LABEL="success"
  fi

  log_activity "ITERATION $i end (run=$RUN_ID agent=$AGENT duration=${ITER_DURATION}s status=$STATUS_LABEL)"
  append_run_summary "$ITER_START_FMT | run=$RUN_ID | iter=$i | agent=$AGENT | duration=${ITER_DURATION}s | status=$STATUS_LABEL"

  # Save run metadata
  RUN_META="$RALPH_RUNS_DIR/run-$RUN_ID-iter-$i.md"
  {
    echo "# Ralph Run: $RUN_ID Iteration $i"
    echo ""
    echo "- Agent: $AGENT"
    echo "- Started: $ITER_START_FMT"
    echo "- Duration: ${ITER_DURATION}s"
    echo "- Status: $STATUS_LABEL"
    echo "- Head (before): ${HEAD_BEFORE:-unknown}"
    echo "- Head (after): ${HEAD_AFTER:-unknown}"
    if [[ "$HEAD_BEFORE" != "$HEAD_AFTER" && -n "$HEAD_BEFORE" && -n "$HEAD_AFTER" ]]; then
      echo ""
      echo "## Commits"
      git -C "$REPO_ROOT" log --oneline "$HEAD_BEFORE..$HEAD_AFTER" | sed 's/^/- /'
    fi
  } > "$RUN_META"

  check_promise

  # Sleep between iterations (except after last iteration)
  if [[ $i -lt $ITERATIONS ]]; then
    sleep "${RALPH_SLEEP_SECONDS:-$SLEEP_DEFAULT}"
  fi
done

log_activity "LOOP END run=$RUN_ID (max iterations reached)"
echo "[ralph] max iterations reached (${ITERATIONS})"
cleanup_artifacts

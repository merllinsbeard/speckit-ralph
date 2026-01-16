# speckit-ralph

Ralph Wiggum Loop - Iterative AI coding CLI for Claude Code and Codex.

## Installation

```bash
# With uv (recommended)
uv tool install speckit-ralph

# With pip
pip install speckit-ralph
```

## Usage

### Single Iteration (HITL Mode)

```bash
# Using Claude Code (default)
ralph once

# Using Codex
ralph once --cli codex

# Keep artifacts for debugging
ralph once --keep-artifacts
```

### Multiple Iterations (AFK Mode)

```bash
# Run 10 iterations with Claude
ralph loop 10

# Run 30 iterations with Codex
ralph loop 30 --cli codex

# Run in background (detached)
ralph loop 20 --detach

# Custom sleep between iterations
ralph loop 10 --sleep 5
```

### Generate Prompt

```bash
# Print prompt to stdout
ralph build-prompt

# Save to file
ralph build-prompt --output /tmp/prompt.md
```

### Get Scripts Path

```bash
# Print path to bundled bash scripts
ralph scripts-path
```

### Guardrails & Activity Log

```bash
# Initialize .ralph directory with default files
ralph init

# Add a new guardrail (sign) interactively
ralph add-sign

# Add a sign via command line
ralph add-sign --name "Check Tests" --trigger "Before commit" --instruction "Run pytest" --reason "Iteration 3"

# Show guardrails
ralph show-guardrails

# Show activity log
ralph show-activity

# Show errors log
ralph show-errors
```

## Guardrails (Signs)

Guardrails are "signs" - lessons learned from failures that help prevent recurring mistakes. They are stored in `.ralph/guardrails.md` and injected into each iteration's prompt.

**Sign format:**

```markdown
### Sign: [Name]

- **Trigger**: When this applies
- **Instruction**: What to do instead
- **Added after**: Why it was added
```

**Types of signs:**

- **Preventive**: Stop problems before they happen
- **Corrective**: Fix recurring mistakes
- **Process**: Enforce good practices
- **Architecture**: Guide design decisions

## Activity Log

Ralph automatically logs all activity to `.ralph/activity.log`:

- Loop start/end events
- Iteration start/end with duration
- Errors and failures

Run summaries are stored in `.ralph/runs/` for each iteration.

## Environment Variables

| Variable                  | Default    | Description                    |
| ------------------------- | ---------- | ------------------------------ |
| `RALPH_PROMISE`           | `COMPLETE` | Completion promise string      |
| `RALPH_SLEEP_SECONDS`     | `2`        | Seconds between iterations     |
| `RALPH_ARTIFACT_DIR`      | (temp)     | Directory for artifacts        |
| `RALPH_SKIP_BRANCH_CHECK` | `0`        | Skip feature branch validation |
| `CLAUDE_BIN`              | `claude`   | Path to Claude CLI             |
| `CODEX_BIN`               | `codex`    | Path to Codex CLI              |

## How It Works

Ralph Wiggum Loop is an iterative development methodology where:

1. The same prompt is fed to the AI repeatedly
2. AI sees its previous work in files and git history (self-reference)
3. AI picks tasks from `tasks.md` and marks them complete
4. Loop continues until `<promise>COMPLETE</promise>` or max iterations

## Requirements

- Python 3.10+
- Claude Code CLI (`claude`) or Codex CLI (`codex`)
- Project must have `specs/<branch>/tasks.md` file
- Must be on a feature branch (e.g., `003-audit-fixes`)

## Learn More

- [Ralph Wiggum Technique](https://ghuntley.com/ralph/)
- [11 Tips for Better Ralph Wiggums](https://www.aihero.dev/11-tips-for-better-ralph-wiggums)

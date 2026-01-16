# 🔄 speckit-ralph

### _Iterative execution engine for SPEC-KIT._

**Automate the Ralph Wiggum Loop for Spec-Driven Development workflows.**

---

## Table of Contents

- [🤔 What is speckit-ralph?](#-what-is-speckit-ralph)
- [⚡ Quick Start](#-quick-start)
- [📽️ How It Works](#️-how-it-works)
- [🤖 Supported AI Agents](#-supported-ai-agents)
- [🔧 CLI Reference](#-cli-reference)
- [🛡️ Guardrails (Signs)](#️-guardrails-signs)
- [📊 Activity Logging](#-activity-logging)
- [⚙️ Environment Variables](#️-environment-variables)
- [🔍 Troubleshooting](#-troubleshooting)
- [📖 Learn More](#-learn-more)
- [📄 License](#-license)

## 🤔 What is speckit-ralph?

[SPEC-KIT](https://github.com/github/spec-kit) is GitHub's official toolkit for **Spec-Driven Development** — a structured approach where specifications become executable, directly generating working implementations.

While SPEC-KIT's `/speckit.implement` runs tasks once, **speckit-ralph automates the iterative loop**:

1. Reads tasks from `specs/<branch>/tasks.md`
2. Feeds them to your AI agent (Claude Code or Codex)
3. Runs multiple iterations until completion
4. Tracks progress, learns from failures, applies guardrails

**Think of it as:** SPEC-KIT defines the "what" and "how", Ralph executes the "do" repeatedly until done.

## ⚡ Quick Start

### 1. Install SPEC-KIT

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
```

### 2. Initialize your project

```bash
specify init my-project --ai claude
cd my-project
```

### 3. Complete SPEC-KIT workflow

```bash
/speckit.specify    # Create specifications
/speckit.plan       # Create implementation plan
/speckit.tasks      # Generate task breakdown
```

### 4. Install speckit-ralph

```bash
uv tool install speckit-ralph
```

### 5. Run the loop

```bash
# Single iteration (HITL mode)
speckit-ralph once

# Multiple iterations (AFK mode)
speckit-ralph loop 10
```

## 📽️ How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    SPEC-KIT Phase                           │
│                   (Human-Guided)                            │
├─────────────────────────────────────────────────────────────┤
│  /speckit.specify  →  specs/<branch>/spec.md               │
│  /speckit.plan     →  specs/<branch>/plan.md               │
│  /speckit.tasks    →  specs/<branch>/tasks.md              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Ralph Phase                              │
│                  (Automated Loop)                           │
├─────────────────────────────────────────────────────────────┤
│  speckit-ralph loop 10                                      │
│    ├─ AI reads tasks.md, spec.md, plan.md                  │
│    ├─ AI implements one task per iteration                 │
│    ├─ AI sees previous work via git history (self-ref)     │
│    └─ Loop continues until:                                │
│        ├─ All tasks complete                               │
│        ├─ <promise>COMPLETE</promise> detected             │
│        └─ Max iterations reached                           │
└─────────────────────────────────────────────────────────────┘
```

## 🤖 Supported AI Agents

| Agent                                        | CLI      | Status |
| -------------------------------------------- | -------- | ------ |
| [Claude Code](https://claude.ai/download)    | `claude` | ✅     |
| [Codex CLI](https://github.com/openai/codex) | `codex`  | ✅     |

## 🔧 CLI Reference

### Commands

| Command                         | Description                    |
| ------------------------------- | ------------------------------ |
| `speckit-ralph once`            | Run a single iteration         |
| `speckit-ralph loop <N>`        | Run N iterations               |
| `speckit-ralph init`            | Initialize .ralph directory    |
| `speckit-ralph add-sign`        | Add a new guardrail            |
| `speckit-ralph show-guardrails` | Display guardrails             |
| `speckit-ralph show-activity`   | Display activity log           |
| `speckit-ralph show-errors`     | Display errors log             |
| `speckit-ralph build-prompt`    | Generate prompt for inspection |
| `speckit-ralph scripts-path`    | Print bundled scripts path     |

### Options

| Option                   | Commands       | Description                       |
| ------------------------ | -------------- | --------------------------------- |
| `--agent`, `-a`          | `once`, `loop` | Agent to use: `claude` or `codex` |
| `--keep-artifacts`, `-k` | `once`, `loop` | Keep temp files for debugging     |
| `--promise`, `-p`        | `once`, `loop` | Completion promise string         |
| `--detach`, `-d`         | `loop`         | Run in background                 |
| `--sleep`, `-s`          | `loop`         | Seconds between iterations        |

### Examples

```bash
# Single iteration with Claude
speckit-ralph once

# Single iteration with Codex
speckit-ralph once --agent codex

# 10 iterations, keep artifacts
speckit-ralph loop 10 --keep-artifacts

# Run in background
speckit-ralph loop 20 --detach

# Custom sleep between iterations
speckit-ralph loop 10 --sleep 5
```

## 🛡️ Guardrails (Signs)

Guardrails are **signs** — lessons learned from failures that prevent recurring mistakes. They are stored in `.ralph/guardrails.md` and injected into each iteration's prompt.

### Adding a Sign

```bash
speckit-ralph add-sign \
  --name "Test Before Commit" \
  --trigger "Before committing changes" \
  --instruction "Run pytest and fix all failures" \
  --reason "Iteration 3 committed broken code"
```

### Sign Format

```markdown
### Sign: [Name]

- **Trigger**: When this applies
- **Instruction**: What to do instead
- **Added after**: Why it was added
```

### Types of Signs

| Type             | Purpose                          |
| ---------------- | -------------------------------- |
| **Preventive**   | Stop problems before they happen |
| **Corrective**   | Fix recurring mistakes           |
| **Process**      | Enforce good practices           |
| **Architecture** | Guide design decisions           |

## 📊 Activity Logging

Ralph automatically logs all activity to `.ralph/activity.log`:

- Loop start/end events
- Iteration start/end with duration
- Errors and failures
- Git HEAD changes per iteration

Run summaries are stored in `.ralph/runs/` with:

- CLI used (claude or codex)
- Duration
- Status (success or error)
- Git commits made

## ⚙️ Environment Variables

| Variable                  | Default                   | Description                    |
| ------------------------- | ------------------------- | ------------------------------ |
| `RALPH_AGENT`             | `claude`                  | Agent: `claude` or `codex`     |
| `RALPH_PROMISE`           | `COMPLETE`                | Completion promise string      |
| `RALPH_SLEEP_SECONDS`     | `2` (claude), `1` (codex) | Seconds between iterations     |
| `RALPH_ARTIFACT_DIR`      | (temp)                    | Directory for artifacts        |
| `RALPH_SKIP_BRANCH_CHECK` | `0`                       | Skip feature branch validation |
| `CLAUDE_BIN`              | `claude`                  | Path to Claude CLI             |
| `CODEX_BIN`               | `codex`                   | Path to Codex CLI              |
| `CODEX_SANDBOX`           | `workspace-write`         | Codex sandbox mode             |
| `CODEX_APPROVAL_POLICY`   | `never`                   | Codex approval policy          |

## 🔍 Troubleshooting

### .specify common script not found

```
ERROR: .specify common script not found
```

**Solution:** Install SPEC-KIT first:

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
specify init . --here --ai claude
```

### plan.md not found

```
ERROR: plan.md not found at specs/<branch>/plan.md
```

**Solution:** Complete the SPEC-KIT workflow:

```bash
/speckit.specify    # Create spec.md
/speckit.plan       # Create plan.md
/speckit.tasks      # Create tasks.md
speckit-ralph loop 10   # Now Ralph can run
```

### Tasks not recognized

**Solution:** Ensure `tasks.md` follows SPEC-KIT format:

```markdown
## User Story 1: [Title]

- [ ] Task 1 description
- [ ] Task 2 description

## User Story 2: [Title]

- [ ] Task 3 description
```

## 📖 Learn More

- **[SPEC-KIT](https://github.com/github/spec-kit)** — GitHub's official Spec-Driven Development toolkit
- **[Spec-Driven Methodology](https://github.com/github/spec-kit/blob/main/spec-driven.md)** — Complete methodology guide
- **[Ralph Wiggum Technique](https://ghuntley.com/ralph/)** — Original methodology
- **[11 Tips for Better Ralph Wiggums](https://www.aihero.dev/11-tips-for-better-ralph-wiggums)** — Best practices

## 📄 License

This project is licensed under the terms of the MIT open source license. See [LICENSE](LICENSE) for details.

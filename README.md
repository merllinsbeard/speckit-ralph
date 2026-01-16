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

### Prerequisites

1. **SPEC-KIT installed and initialized** in your project
2. **Spec workflow complete**: `spec.md`, `plan.md`, `tasks.md` exist in `specs/<branch>/`
3. **Feature branch** matching your spec directory (e.g., `feature/auth` → `specs/feature/auth/`)

### Installation

```bash
uv tool install speckit-ralph --from git+https://github.com/merllinsbeard/speckit-ralph.git
```

### Usage

```bash
# 1. Checkout your feature branch
git checkout feature/my-feature

# 2. Initialize Ralph (creates .speckit-ralph/ directory)
speckit-ralph init

# 3. Run the loop
speckit-ralph once --agent claude      # Single iteration (review each step)
speckit-ralph loop 10 --agent claude   # Multiple iterations (AFK mode)
```

### Optional: Inspect the prompt

```bash
# See what Ralph will send to the AI agent
speckit-ralph build-prompt

# Save to file for review
speckit-ralph build-prompt --output prompt.md
```

### New to SPEC-KIT?

If you haven't set up SPEC-KIT yet:

```bash
# Install SPEC-KIT
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# Initialize in your project
specify init . --here --ai claude

# Create spec workflow (in Claude Code)
/speckit.specify    # Create specifications
/speckit.plan       # Create implementation plan
/speckit.tasks      # Generate task breakdown

# Then install and run Ralph
uv tool install speckit-ralph --from git+https://github.com/merllinsbeard/speckit-ralph.git
speckit-ralph init
speckit-ralph loop 10 --agent claude
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
│  speckit-ralph loop 10 --agent claude                       │
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

| Command                         | Description                         |
| ------------------------------- | ----------------------------------- |
| `speckit-ralph once`            | Run a single iteration              |
| `speckit-ralph loop <N>`        | Run N iterations                    |
| `speckit-ralph init`            | Initialize .speckit-ralph directory |
| `speckit-ralph show-guardrails` | Display guardrails                  |
| `speckit-ralph show-activity`   | Display activity log                |
| `speckit-ralph show-errors`     | Display errors log                  |
| `speckit-ralph build-prompt`    | Generate prompt for inspection      |
| `speckit-ralph scripts-path`    | Print bundled scripts path          |

### Options

| Option                   | Commands                                                  | Description                                      |
| ------------------------ | --------------------------------------------------------- | ------------------------------------------------ |
| `--agent`, `-a`          | `once`, `loop`                                            | **Required.** Agent: `claude` or `codex`         |
| `--keep-artifacts`, `-k` | `once`, `loop`                                            | Keep temp files for debugging                    |
| `--promise`, `-p`        | `once`, `loop`                                            | Completion promise string                        |
| `--detach`, `-d`         | `loop`                                                    | Run in background                                |
| `--sleep`, `-s`          | `loop`                                                    | Seconds between iterations                       |
| `--spec`, `-S`           | `once`, `loop`, `build-prompt`                            | Spec directory path (overrides branch detection) |
| `--root`, `-r`           | `init`, `show-activity`, `show-errors`, `show-guardrails` | Project root directory                           |
| `--lines`, `-n`          | `show-activity`, `show-errors`                            | Number of lines to show (default: 50)            |
| `--output`, `-o`         | `build-prompt`                                            | Output file path                                 |

### Examples

```bash
# Single iteration with Claude
speckit-ralph once --agent claude

# Single iteration with Codex
speckit-ralph once --agent codex

# 10 iterations with Claude, keep artifacts
speckit-ralph loop 10 --agent claude --keep-artifacts

# Run Codex in background
speckit-ralph loop 20 --agent codex --detach

# Custom sleep between iterations
speckit-ralph loop 10 --agent claude --sleep 5

# Multi-spec: explicitly specify which spec to use
speckit-ralph loop 5 --agent claude --spec specs/feature/auth
speckit-ralph once --agent codex --spec specs/feature/payments
```

### Multi-Spec Projects

By default, Ralph detects which spec to use based on your current git branch name (e.g., `feature/auth` maps to `specs/feature/auth/`).

For projects with multiple specs, you can explicitly specify which spec to use:

```bash
# Override branch detection with --spec
speckit-ralph loop 10 --agent claude --spec specs/feature/auth

# Use relative path from repo root
speckit-ralph once --agent codex --spec specs/feature/payments

# Or absolute path
speckit-ralph loop 5 --agent claude --spec /path/to/my-project/specs/feature/checkout
```

**When to use `--spec`:**

- Working on a different spec than your current branch
- Running multiple loops in parallel for different specs
- Testing a spec from a non-feature branch (e.g., `main`)

## 🛡️ Guardrails (Signs)

Guardrails are **signs** — lessons learned from failures that prevent recurring mistakes. They are stored in `.speckit-ralph/guardrails.md` and injected into each iteration's prompt.

Edit `.speckit-ralph/guardrails.md` directly to add new signs.

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

Ralph automatically logs all activity to `.speckit-ralph/activity.log`:

- Loop start/end events
- Iteration start/end with duration
- Errors and failures
- Git HEAD changes per iteration

Run summaries are stored in `.speckit-ralph/runs/` with:

- CLI used (claude or codex)
- Duration
- Status (success or error)
- Git commits made

## ⚙️ Environment Variables

| Variable                  | Default                   | Description                          |
| ------------------------- | ------------------------- | ------------------------------------ |
| `RALPH_AGENT`             | `claude`                  | Agent: `claude` or `codex`           |
| `RALPH_PROMISE`           | `COMPLETE`                | Completion promise string            |
| `RALPH_SLEEP_SECONDS`     | `2` (claude), `1` (codex) | Seconds between iterations           |
| `RALPH_ARTIFACT_DIR`      | (temp)                    | Directory for artifacts              |
| `RALPH_SKIP_BRANCH_CHECK` | `0`                       | Skip feature branch validation       |
| `RALPH_SPEC_DIR`          | (auto)                    | Override spec directory (multi-spec) |
| `CODEX_SANDBOX`           | `workspace-write`         | Codex sandbox mode                   |
| `CODEX_APPROVAL_POLICY`   | `never`                   | Codex approval policy                |

## 🔍 Troubleshooting

### SPEC-KIT not initialized

```
ERROR: SPEC-KIT not initialized in this project.
```

**Solution:** Ralph requires SPEC-KIT to be set up first. Run these commands:

```bash
# 1. Install SPEC-KIT
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# 2. Initialize SPEC-KIT in your project
specify init . --here --ai claude

# 3. Create your spec in Claude Code
/speckit.specify
/speckit.plan
/speckit.tasks

# 4. Now Ralph can run
speckit-ralph init
speckit-ralph loop 10
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

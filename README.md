# speckit-ralph

**Ralph Wiggum Loop - Iterative execution engine for [SPEC-KIT](https://github.com/github/spec-kit) workflows.**

Build high-quality software faster by automating the implementation phase of Spec-Driven Development.

---

## What is SPEC-KIT?

[SPEC-KIT](https://github.com/github/spec-kit) is GitHub's official toolkit for **Spec-Driven Development** - a structured approach where specifications become executable, directly generating working implementations. SPEC-KIT provides:

- **`/speckit.specify`** - Define what you want to build (requirements and user stories)
- **`/speckit.plan`** - Create technical implementation plans with your chosen tech stack
- **`/speckit.tasks`** - Generate actionable task lists for implementation
- **`/speckit.implement`** - Execute all tasks to build the feature

SPEC-KIT creates a structured workflow with specifications, plans, and tasks in a `specs/<feature>/` directory.

## What is Ralph?

**Ralph is the execution engine for SPEC-KIT's implementation phase.**

While SPEC-KIT's `/speckit.implement` command runs tasks once, **Ralph automates the iterative loop**:

1. Reads tasks from `specs/<branch>/tasks.md` (created by SPEC-KIT)
2. Feeds them to your AI agent (Claude Code or Codex)
3. Runs multiple iterations until completion
4. Tracks progress, learns from failures, and applies guardrails

Ralph implements the **Ralph Wiggum methodology** - where the AI sees its previous work in files and git history (self-reference), picks tasks iteratively, and continues until all tasks are complete or a promise signal is detected.

**Think of it as:** SPEC-KIT defines the "what" and "how", Ralph executes the "do" repeatedly until done.

---

## Installation

### Prerequisites

1. **Install SPEC-KIT first** (Ralph depends on SPEC-KIT's directory structure):

```bash
# Install SPEC-KIT
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# Initialize your project with SPEC-KIT
specify init my-project --ai claude
cd my-project

# Follow SPEC-KIT workflow to create specs and tasks
/speckit.specify    # Create specifications
/speckit.plan       # Create implementation plan
/speckit.tasks      # Generate task breakdown
```

2. **Install Ralph** (after SPEC-KIT setup):

```bash
# With uv (recommended)
uv tool install speckit-ralph

# With pip
pip install speckit-ralph
```

3. **Install AI agent CLI**:
   - [Claude Code](https://claude.ai/download) - `claude` command
   - [Codex CLI](https://github.com/openai/codex) - `codex` command

---

## Usage

### Single Iteration (HITL Mode)

Run one iteration and review results before continuing:

```bash
# Using Claude Code (default)
ralph once

# Using Codex
ralph once --agent codex

# Keep artifacts for debugging
ralph once --keep-artifacts
```

### Multiple Iterations (AFK Mode)

Run multiple iterations until completion:

```bash
# Run 10 iterations with Claude
ralph loop 10

# Run 30 iterations with Codex
ralph loop 30 --agent codex

# Run in background (detached)
ralph loop 20 --detach

# Custom sleep between iterations
ralph loop 10 --sleep 5
```

### Guardrails & Activity Log

Ralph tracks failures and learns from them:

```bash
# Initialize .ralph directory with default files
ralph init

# Add a new guardrail (sign) after a failure
ralph add-sign --name "Run Tests Before Commit" \
               --trigger "Before git commit" \
               --instruction "Run pytest and fix failures" \
               --reason "Iteration 5 failed due to untested code"

# View guardrails (injected into every iteration)
ralph show-guardrails

# View activity log
ralph show-activity

# View errors log
ralph show-errors
```

### Other Commands

```bash
# Generate prompt for inspection
ralph build-prompt --output /tmp/prompt.md

# Get path to bundled scripts
ralph scripts-path
```

---

## How It Works

Ralph implements the **Ralph Wiggum Loop** methodology for SPEC-KIT projects:

### The SPEC-KIT + Ralph Workflow

```
1. SPEC-KIT Phase (Human-Guided)
   ├─ /speckit.specify → specs/<branch>/spec.md
   ├─ /speckit.plan → specs/<branch>/plan.md
   └─ /speckit.tasks → specs/<branch>/tasks.md

2. Ralph Phase (Automated Loop)
   ├─ ralph loop 10
   ├─ AI reads tasks.md, spec.md, plan.md
   ├─ AI implements one task per iteration
   ├─ AI sees previous work via git history (self-reference)
   ├─ Loop continues until:
   │  ├─ All tasks complete
   │  ├─ <promise>COMPLETE</promise> detected
   │  └─ Max iterations reached
   └─ Guardrails prevent repeated failures
```

### What Ralph Provides

- **Iterative execution**: Runs the same prompt repeatedly, letting AI self-correct
- **Self-reference**: AI sees its previous work in files and git commits
- **Progress tracking**: Logs every iteration with duration, status, git changes
- **Failure learning**: Converts failures into guardrails (signs) for future iterations
- **Agent flexibility**: Works with Claude Code or Codex
- **Background execution**: Detach mode for long-running loops

---

## Requirements

Ralph requires a SPEC-KIT-initialized project with:

- **SPEC-KIT** installed (`specify-cli`)
- **Python 3.10+**
- **Claude Code CLI** (`claude`) or **Codex CLI** (`codex`)
- **Git repository** with feature branch
- **SPEC-KIT directory structure**:
  - `.specify/` - SPEC-KIT scripts and templates
  - `specs/<branch>/` - Feature specifications
  - `specs/<branch>/tasks.md` - Task list (created by `/speckit.tasks`)
  - `specs/<branch>/spec.md` - Requirements
  - `specs/<branch>/plan.md` - Implementation plan

Ralph will fail with an error if `.specify/scripts/bash/common.sh` is not found (SPEC-KIT dependency).

---

## Environment Variables

| Variable                  | Default                   | Description                    |
| ------------------------- | ------------------------- | ------------------------------ |
| `RALPH_AGENT`             | `claude`                  | Agent to use: claude or codex  |
| `RALPH_PROMISE`           | `COMPLETE`                | Completion promise string      |
| `RALPH_SLEEP_SECONDS`     | `2` (claude), `1` (codex) | Seconds between iterations     |
| `RALPH_ARTIFACT_DIR`      | (temp)                    | Directory for artifacts        |
| `RALPH_SKIP_BRANCH_CHECK` | `0`                       | Skip feature branch validation |
| `CLAUDE_BIN`              | `claude`                  | Path to Claude CLI             |
| `CODEX_BIN`               | `codex`                   | Path to Codex CLI              |
| `CODEX_SANDBOX`           | `workspace-write`         | Codex sandbox mode             |
| `CODEX_APPROVAL_POLICY`   | `never`                   | Codex approval policy          |

---

## Guardrails (Signs)

Guardrails are "signs" - lessons learned from failures that help prevent recurring mistakes. They are stored in `.ralph/guardrails.md` and injected into each iteration's prompt.

**Sign format:**

```markdown
### Sign: [Name]

- **Trigger**: When this applies
- **Instruction**: What to do instead
- **Added after**: Why it was added
```

**Example workflow:**

```bash
# Iteration 3 fails because tests weren't run
ralph add-sign --name "Test Before Commit" \
               --trigger "Before committing changes" \
               --instruction "Run pytest and fix all failures" \
               --reason "Iteration 3 committed broken code"

# Next iteration reads this guardrail and follows it
ralph loop 10
```

**Types of signs:**

- **Preventive**: Stop problems before they happen
- **Corrective**: Fix recurring mistakes
- **Process**: Enforce good practices
- **Architecture**: Guide design decisions

---

## Activity Log

Ralph automatically logs all activity to `.ralph/activity.log`:

- Loop start/end events
- Iteration start/end with duration
- Errors and failures
- Git HEAD changes per iteration

Run summaries are stored in `.ralph/runs/` for each iteration with:

- CLI used (claude or codex)
- Duration
- Status (success or error)
- Git commits made

---

## Troubleshooting

### Error: ".specify common script not found"

```
ERROR: .specify common script not found at /path/to/project/.specify/scripts/bash/common.sh
Run speckit setup first.
```

**Solution:** Ralph requires SPEC-KIT to be installed. Run:

```bash
# Initialize SPEC-KIT in your project
specify init . --here --ai claude

# Or if already initialized elsewhere:
# Make sure you're in a SPEC-KIT project directory
cd /path/to/your/speckit-project
```

### Error: "plan.md not found"

```
ERROR: plan.md not found at specs/<branch>/plan.md
```

**Solution:** Ralph expects SPEC-KIT's directory structure. Complete the SPEC-KIT workflow first:

```bash
/speckit.specify    # Create spec.md
/speckit.plan       # Create plan.md
/speckit.tasks      # Create tasks.md
ralph loop 10       # Now Ralph can run
```

### Ralph doesn't understand SPEC-KIT tasks

**Solution:** Ralph works best when tasks.md follows SPEC-KIT's format (created by `/speckit.tasks`). If you manually edited tasks.md, ensure it follows this structure:

```markdown
## User Story 1: [Title]

- [ ] Task 1 description
- [ ] Task 2 description

## User Story 2: [Title]

- [ ] Task 3 description
```

---

## Learn More

- **[SPEC-KIT Repository](https://github.com/github/spec-kit)** - GitHub's official Spec-Driven Development toolkit
- **[Spec-Driven Development Methodology](https://github.com/github/spec-kit/blob/main/spec-driven.md)** - Complete guide to the methodology
- **[Ralph Wiggum Technique](https://ghuntley.com/ralph/)** - Original Ralph methodology
- **[11 Tips for Better Ralph Wiggums](https://www.aihero.dev/11-tips-for-better-ralph-wiggums)** - Best practices

---

## Project Identity

**speckit-ralph** = Ralph Wiggum Loop + SPEC-KIT integration

- **Ralph Wiggum Loop**: Iterative AI development methodology (self-referential execution)
- **SPEC-KIT**: GitHub's Spec-Driven Development toolkit (structured planning)
- **speckit-ralph**: The execution engine that automates Ralph loops for SPEC-KIT workflows

Ralph is to SPEC-KIT what a CI/CD runner is to a build pipeline - it executes the plan repeatedly until completion.

---

## License

MIT License - See [LICENSE](LICENSE) for details.

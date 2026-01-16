# Repository Guidelines

## Project Overview

**speckit-ralph** is the iterative execution engine for [SPEC-KIT](https://github.com/github/spec-kit) workflows. Ralph automates the Ralph Wiggum Loop methodology for SPEC-KIT projects, reading tasks from `specs/<branch>/tasks.md` and executing them iteratively until completion.

## Project Structure & Module Organization

- `src/speckit_ralph/` holds the Python package. The CLI entrypoint is `src/speckit_ralph/cli.py`.
- `src/speckit_ralph/scripts/` contains bundled shell scripts and prompt assets used by the Ralph loop.
  - `agent-commands.sh` - Agent command templates (claude, codex)
  - `ralph-env.sh` - Environment setup and path resolution (requires SPEC-KIT's `.specify/` directory)
  - `ralph-once.sh` - Unified single iteration script (supports --agent parameter)
  - `ralph-loop.sh` - Unified multi-iteration loop script (supports --agent parameter)
  - `build-prompt.sh` - Generates prompts from SPEC-KIT templates
  - `prompt-template.md` - Prompt template with SPEC-KIT variable substitution
- `src/speckit_ralph/templates/` stores markdown templates (guardrails, activity, errors).
- Project metadata and build config live in `pyproject.toml`.

## Build, Test, and Development Commands

- `uv tool install speckit-ralph` or `pip install speckit-ralph`: install the CLI.
- `ralph once` / `ralph loop <n>`: run single or multi-iteration loops.
- `ralph build-prompt --output /tmp/prompt.md`: generate a prompt file for inspection.
- `ralph init`: create a `.ralph/` directory with guardrails and logs.
- `ralph scripts-path`: print the path to packaged helper scripts.

## Coding Style & Naming Conventions

- Python 3.10+, 4-space indentation, and module names in `snake_case`.
- CLI commands are lower-case verbs (e.g., `ralph build-prompt`).
- If available locally, use `ruff check .` and `ruff format --check .` for linting/formatting.

## Testing Guidelines

- No test suite is currently in the repository.
- When adding tests, prefer `pytest` with files named `test_*.py` under a top-level `tests/` directory.
- Scope test runs to the smallest relevant area (e.g., `pytest tests/test_cli.py`).

## Commit & Pull Request Guidelines

- Commits use short, imperative, sentence-case summaries (e.g., “Add Guardrails and Activity Log features”).
- PRs should describe behavior changes, list any new commands or flags, and note doc/script updates.
- Include CLI examples when user-facing behavior changes (command + expected output snippet).

## Security & Configuration Tips

- Runtime behavior is driven by env vars like `RALPH_PROMISE`, `RALPH_SLEEP_SECONDS`, `CODEX_BIN`, and `CLAUDE_BIN`.
- Avoid committing `.ralph/` artifacts or run logs unless explicitly requested.

## SPEC-KIT Integration

- **Hard dependency**: Ralph requires [SPEC-KIT](https://github.com/github/spec-kit) to be installed and initialized in the project.
- `ralph-env.sh` sources `.specify/scripts/bash/common.sh` (SPEC-KIT's core script).
- Expects SPEC-KIT directory structure: `specs/<branch>/spec.md`, `specs/<branch>/plan.md`, `specs/<branch>/tasks.md`.
- Workflow: Use SPEC-KIT's `/speckit.specify`, `/speckit.plan`, `/speckit.tasks` commands first, then `ralph loop` to execute.

## Agent-Specific Notes

- This repo implements the Ralph Wiggum Loop methodology for SPEC-KIT projects.
- Ralph reads tasks from `specs/<feature>/tasks.md` (created by SPEC-KIT's `/speckit.tasks` command).
- The scripts assume a feature-branch workflow; use `RALPH_SKIP_BRANCH_CHECK=1` only when necessary.
- Supports both Claude Code (`ralph once --agent claude`) and Codex (`ralph once --agent codex`) as execution agents.
- The `--agent` parameter replaced the old `--cli` parameter in the recent refactoring.

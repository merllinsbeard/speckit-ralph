# Ralph Loop Prompt (Codex)

You are Codex running a Ralph-style loop for this repo.

## Context

- Repo root: {{REPO_ROOT}}
- Feature dir: {{FEATURE_DIR}}
- Spec: {{FEATURE_SPEC}}
- Plan: {{IMPL_PLAN}}
- Tasks: {{TASKS}}
- Progress log: {{PROGRESS_FILE}}
- Research: {{RESEARCH}}
- Data model: {{DATA_MODEL}}
- Contracts: {{CONTRACTS_DIR}}
- Quickstart: {{QUICKSTART}}
- GitHub repo: {{REPO_SLUG}}

## Guardrails (Signs)

Before acting, review these lessons learned from previous iterations:

{{GUARDRAILS}}

## Non-negotiable rules

1. Read and follow {{REPO_ROOT}}/AGENTS.md.
2. Work on EXACTLY ONE task per iteration.
3. Keep changes small and focused (one logical change per commit).
4. Use feedback loops before committing.
5. Update progress log after each completed task.

## Task selection

- Use {{TASKS}} as the source of truth.
- Pick the next unchecked task. Prioritize higher priority stories and risky integration work.
- If a task is blocked, record why in {{PROGRESS_FILE}} and pick a different task.

## Execution steps per iteration

1. Read AGENTS.md, spec, plan, tasks, and progress log.
2. Choose ONE task to complete.
3. Implement the task (TDD if the task is a test task).
4. Run feedback loops:
   - ruff check .
   - ruff format --check .
   - pytest for the touched tests or the smallest relevant scope
5. Update {{PROGRESS_FILE}} with:
   - Task ID + short description
   - Decisions and rationale
   - Files changed
   - Tests run (with results)
   - Blockers or follow-ups
6. Commit with a short imperative message that includes the task ID (e.g., "T012 Add ...").

## Completion rule

If ALL tasks are complete and all feedback loops pass, output:
<promise>{{PROMISE}}</promise>

## GitHub integration (optional)

- If RALPH_GH_ISSUE is set and gh is available, comment a short summary on that issue.
- If RALPH_GH_CREATE_PR=1, open a PR at the end of the iteration.

## Safety

- Do not run destructive commands.
- Do not modify tasks.md unless explicitly required by the spec.

"""Ralph Wiggum Loop CLI."""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import typer
from rich.console import Console
from rich.markdown import Markdown
from rich.prompt import Prompt

app = typer.Typer(
    name="ralph",
    help="Ralph Wiggum Loop - Iterative AI coding for Claude Code and Codex",
    no_args_is_help=True,
)
console = Console()

# =============================================================================
# Ralph Directory Management
# =============================================================================

RALPH_DIR_NAME = ".ralph"
GUARDRAILS_FILE = "guardrails.md"
ACTIVITY_LOG_FILE = "activity.log"
ERRORS_LOG_FILE = "errors.log"
RUNS_DIR_NAME = "runs"


def resolve_root(root: Path | None) -> Path:
    """Resolve project root directory."""
    return root if root is not None else Path.cwd()


def get_ralph_dir(root: Path | None = None) -> Path:
    """Get the .ralph directory path."""
    return resolve_root(root) / RALPH_DIR_NAME


def get_templates_dir() -> Path:
    """Get the path to bundled templates directory."""
    return Path(__file__).parent / "templates"


def get_scripts_dir() -> Path:
    """Get the path to bundled scripts directory."""
    return Path(__file__).parent / "scripts"


def run_script(script_name: str, args: list[str] | None = None, env: dict | None = None) -> int:
    """Run a bash script from the scripts directory."""
    script_path = get_scripts_dir() / script_name

    if not script_path.exists():
        console.print(f"[red]Error: Script not found: {script_path}[/red]")
        return 1

    cmd = ["bash", str(script_path)]
    if args:
        cmd.extend(args)

    run_env = os.environ.copy()
    if env:
        run_env.update(env)

    try:
        result = subprocess.run(cmd, env=run_env)
        return result.returncode
    except FileNotFoundError:
        console.print("[red]Error: bash not found[/red]")
        return 1
    except PermissionError:
        console.print(f"[red]Error: Permission denied: {script_path}[/red]")
        return 1


@app.command()
def once(
    agent: str = typer.Option("claude", "--agent", "-a", help="Agent to use: claude or codex"),
    keep_artifacts: bool = typer.Option(False, "--keep-artifacts", "-k", help="Keep temp files for debugging"),
    promise: str = typer.Option("COMPLETE", "--promise", "-p", help="Completion promise string"),
):
    """Run a single Ralph iteration."""
    env = {"RALPH_PROMISE": promise, "RALPH_AGENT": agent}
    if keep_artifacts:
        env["RALPH_ARTIFACT_DIR"] = str(Path(tempfile.gettempdir()) / f"ralph-{agent}-debug")

    sys.exit(run_script("ralph-once.sh", env=env))


@app.command()
def loop(
    iterations: int = typer.Argument(..., help="Number of iterations to run"),
    agent: str = typer.Option("claude", "--agent", "-a", help="Agent to use: claude or codex"),
    detach: bool = typer.Option(False, "--detach", "-d", help="Run in background"),
    keep_artifacts: bool = typer.Option(False, "--keep-artifacts", "-k", help="Keep temp files"),
    promise: str = typer.Option("COMPLETE", "--promise", "-p", help="Completion promise string"),
    sleep: int | None = typer.Option(None, "--sleep", "-s", help="Seconds between iterations"),
):
    """Run Ralph loop for multiple iterations."""
    args = [str(iterations), "--agent", agent]
    if detach:
        args.append("--detach")
    if sleep is not None:
        args.extend(["--sleep", str(sleep)])

    env = {"RALPH_PROMISE": promise, "RALPH_AGENT": agent}
    if keep_artifacts:
        env["RALPH_ARTIFACT_DIR"] = str(Path(tempfile.gettempdir()) / f"ralph-{agent}-loop")
    if sleep is not None:
        env["RALPH_SLEEP_SECONDS"] = str(sleep)

    sys.exit(run_script("ralph-loop.sh", args=args, env=env))


@app.command()
def build_prompt(
    output: Path | None = typer.Option(None, "--output", "-o", help="Output file path"),
) -> None:
    """Generate Ralph prompt from template."""
    args = []
    if output:
        args.extend(["--output", str(output)])

    sys.exit(run_script("build-prompt.sh", args=args))


@app.command()
def scripts_path() -> None:
    """Print path to bundled scripts directory."""
    console.print(get_scripts_dir())


# =============================================================================
# Guardrails & Activity Log Commands
# =============================================================================


@app.command()
def init(
    root: Path | None = typer.Option(None, "--root", "-r", help="Project root directory"),
) -> None:
    """Initialize .ralph directory with default files."""
    root = resolve_root(root)
    ralph_dir = get_ralph_dir(root)
    runs_dir = ralph_dir / RUNS_DIR_NAME
    templates_dir = get_templates_dir()

    # Create directories
    ralph_dir.mkdir(parents=True, exist_ok=True)
    runs_dir.mkdir(parents=True, exist_ok=True)

    # Copy templates if files don't exist
    template_mapping = {
        "guardrails.md": GUARDRAILS_FILE,
        "activity.md": ACTIVITY_LOG_FILE,
        "errors.md": ERRORS_LOG_FILE,
    }

    created = []
    for template_name, target_name in template_mapping.items():
        target_path = ralph_dir / target_name
        template_path = templates_dir / template_name

        if not target_path.exists() and template_path.exists():
            shutil.copy(template_path, target_path)
            created.append(target_name)

    if created:
        console.print(f"[green]Initialized .ralph directory at {ralph_dir}[/green]")
        for name in created:
            console.print(f"  - Created {name}")
    else:
        console.print(f"[yellow].ralph directory already exists at {ralph_dir}[/yellow]")


@app.command()
def add_sign(
    root: Path | None = typer.Option(None, "--root", "-r", help="Project root directory"),
    name: str | None = typer.Option(None, "--name", "-n", help="Sign name"),
    trigger: str | None = typer.Option(None, "--trigger", "-t", help="When this sign applies"),
    instruction: str | None = typer.Option(None, "--instruction", "-i", help="What to do"),
    reason: str | None = typer.Option(None, "--reason", help="Why this sign was added"),
) -> None:
    """Add a new guardrail (sign) interactively or via options."""
    root = resolve_root(root)
    ralph_dir = get_ralph_dir(root)
    guardrails_path = ralph_dir / GUARDRAILS_FILE

    if not guardrails_path.exists():
        console.print("[red]Error: .ralph/guardrails.md not found. Run 'ralph init' first.[/red]")
        raise typer.Exit(1)

    # Interactive prompts for missing values
    if name is None:
        name = Prompt.ask("[bold]Sign name[/bold]")
    if trigger is None:
        trigger = Prompt.ask("[bold]Trigger[/bold] (when does this apply?)")
    if instruction is None:
        instruction = Prompt.ask("[bold]Instruction[/bold] (what to do instead?)")
    if reason is None:
        reason = Prompt.ask("[bold]Added after[/bold] (why was this added?)", default="Manual addition")

    # Build the sign block
    sign_block = f"""
### Sign: {name}
- **Trigger**: {trigger}
- **Instruction**: {instruction}
- **Added after**: {reason}
"""

    # Append to guardrails file
    with guardrails_path.open("a", encoding="utf-8") as f:
        f.write(sign_block)

    console.print(f"[green]Added sign: {name}[/green]")


@app.command()
def show_activity(
    root: Path | None = typer.Option(None, "--root", "-r", help="Project root directory"),
    lines: int = typer.Option(50, "--lines", "-n", help="Number of lines to show"),
) -> None:
    """Display the activity log."""
    root = resolve_root(root)
    ralph_dir = get_ralph_dir(root)
    activity_path = ralph_dir / ACTIVITY_LOG_FILE

    if not activity_path.exists():
        console.print("[red]Error: .ralph/activity.log not found. Run 'ralph init' first.[/red]")
        raise typer.Exit(1)

    content = activity_path.read_text(encoding="utf-8")
    content_lines = content.splitlines()

    if len(content_lines) > lines:
        content_lines = content_lines[-lines:]
        content = "\n".join(content_lines)

    console.print(Markdown(content))


@app.command()
def show_errors(
    root: Path | None = typer.Option(None, "--root", "-r", help="Project root directory"),
    lines: int = typer.Option(50, "--lines", "-n", help="Number of lines to show"),
) -> None:
    """Display the errors log."""
    root = resolve_root(root)
    ralph_dir = get_ralph_dir(root)
    errors_path = ralph_dir / ERRORS_LOG_FILE

    if not errors_path.exists():
        console.print("[red]Error: .ralph/errors.log not found. Run 'ralph init' first.[/red]")
        raise typer.Exit(1)

    content = errors_path.read_text(encoding="utf-8")
    content_lines = content.splitlines()

    if len(content_lines) > lines:
        content_lines = content_lines[-lines:]
        content = "\n".join(content_lines)

    console.print(Markdown(content))


@app.command()
def show_guardrails(
    root: Path | None = typer.Option(None, "--root", "-r", help="Project root directory"),
) -> None:
    """Display the guardrails (signs)."""
    root = resolve_root(root)
    ralph_dir = get_ralph_dir(root)
    guardrails_path = ralph_dir / GUARDRAILS_FILE

    if not guardrails_path.exists():
        console.print("[red]Error: .ralph/guardrails.md not found. Run 'ralph init' first.[/red]")
        raise typer.Exit(1)

    content = guardrails_path.read_text(encoding="utf-8")
    console.print(Markdown(content))


if __name__ == "__main__":
    app()

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

app = typer.Typer(
    name="speckit-ralph",
    help="Ralph Wiggum Loop - Iterative AI coding for Claude Code and Codex",
    no_args_is_help=True,
)
console = Console()

# =============================================================================
# Ralph Directory Management
# =============================================================================

RALPH_DIR_NAME = ".speckit-ralph"
GUARDRAILS_FILE = "guardrails.md"
ACTIVITY_LOG_FILE = "activity.log"
ERRORS_LOG_FILE = "errors.log"
RUNS_DIR_NAME = "runs"


def get_ralph_dir(root: Path | None = None) -> Path:
    """Get the .speckit-ralph directory path, defaulting to current directory."""
    return (root or Path.cwd()) / RALPH_DIR_NAME


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
    agent: str = typer.Option(..., "--agent", "-a", help="Agent to use: claude or codex"),
    keep_artifacts: bool = typer.Option(False, "--keep-artifacts", "-k", help="Keep temp files for debugging"),
    promise: str = typer.Option("COMPLETE", "--promise", "-p", help="Completion promise string"),
    spec: str | None = typer.Option(None, "--spec", "-S", help="Spec directory path (overrides branch detection)"),
):
    """Run a single Ralph iteration."""
    env = {"RALPH_PROMISE": promise, "RALPH_AGENT": agent}
    if keep_artifacts:
        env["RALPH_ARTIFACT_DIR"] = str(Path(tempfile.gettempdir()) / f"ralph-{agent}-debug")
    if spec:
        env["RALPH_SPEC_DIR"] = spec

    sys.exit(run_script("ralph-once.sh", env=env))


@app.command()
def loop(
    iterations: int = typer.Argument(..., help="Number of iterations to run"),
    agent: str = typer.Option(..., "--agent", "-a", help="Agent to use: claude or codex"),
    detach: bool = typer.Option(False, "--detach", "-d", help="Run in background"),
    keep_artifacts: bool = typer.Option(False, "--keep-artifacts", "-k", help="Keep temp files"),
    promise: str = typer.Option("COMPLETE", "--promise", "-p", help="Completion promise string"),
    sleep: int | None = typer.Option(None, "--sleep", "-s", help="Seconds between iterations"),
    spec: str | None = typer.Option(None, "--spec", "-S", help="Spec directory path (overrides branch detection)"),
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
    if spec:
        env["RALPH_SPEC_DIR"] = spec

    sys.exit(run_script("ralph-loop.sh", args=args, env=env))


@app.command()
def build_prompt(
    output: Path | None = typer.Option(None, "--output", "-o", help="Output file path"),
    spec: str | None = typer.Option(None, "--spec", "-S", help="Spec directory path (overrides branch detection)"),
) -> None:
    """Generate Ralph prompt from template."""
    args = ["--output", str(output)] if output else []
    env = {"RALPH_SPEC_DIR": spec} if spec else None

    sys.exit(run_script("build-prompt.sh", args=args, env=env))


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
    """Initialize .speckit-ralph directory with default files."""
    ralph_dir = get_ralph_dir(root)
    templates_dir = get_templates_dir()

    ralph_dir.mkdir(parents=True, exist_ok=True)
    (ralph_dir / RUNS_DIR_NAME).mkdir(parents=True, exist_ok=True)

    template_files = [
        ("guardrails.md", GUARDRAILS_FILE),
        ("activity.md", ACTIVITY_LOG_FILE),
        ("errors.md", ERRORS_LOG_FILE),
    ]

    created = []
    for template_name, target_name in template_files:
        target_path = ralph_dir / target_name
        template_path = templates_dir / template_name

        if not target_path.exists() and template_path.exists():
            shutil.copy(template_path, target_path)
            created.append(target_name)

    if created:
        console.print(f"[green]Initialized .speckit-ralph directory at {ralph_dir}[/green]")
        for name in created:
            console.print(f"  - Created {name}")
    else:
        console.print(f"[yellow].speckit-ralph directory already exists at {ralph_dir}[/yellow]")


def _show_log_file(filename: str, root: Path | None, lines: int) -> None:
    """Display a log file with optional line limit."""
    ralph_dir = get_ralph_dir(root)
    file_path = ralph_dir / filename

    if not file_path.exists():
        console.print(f"[red]Error: .speckit-ralph/{filename} not found. Run 'speckit-ralph init' first.[/red]")
        raise typer.Exit(1)

    content = file_path.read_text(encoding="utf-8")
    content_lines = content.splitlines()

    if len(content_lines) > lines:
        content = "\n".join(content_lines[-lines:])

    console.print(Markdown(content))


@app.command()
def show_activity(
    root: Path | None = typer.Option(None, "--root", "-r", help="Project root directory"),
    lines: int = typer.Option(50, "--lines", "-n", help="Number of lines to show"),
) -> None:
    """Display the activity log."""
    _show_log_file(ACTIVITY_LOG_FILE, root, lines)


@app.command()
def show_errors(
    root: Path | None = typer.Option(None, "--root", "-r", help="Project root directory"),
    lines: int = typer.Option(50, "--lines", "-n", help="Number of lines to show"),
) -> None:
    """Display the errors log."""
    _show_log_file(ERRORS_LOG_FILE, root, lines)


@app.command()
def show_guardrails(
    root: Path | None = typer.Option(None, "--root", "-r", help="Project root directory"),
) -> None:
    """Display the guardrails (signs)."""
    guardrails_path = get_ralph_dir(root) / GUARDRAILS_FILE

    if not guardrails_path.exists():
        console.print("[red]Error: .speckit-ralph/guardrails.md not found. Run 'speckit-ralph init' first.[/red]")
        raise typer.Exit(1)

    console.print(Markdown(guardrails_path.read_text(encoding="utf-8")))


if __name__ == "__main__":
    app()

# Contributing

Thanks for your interest! This project deliberately keeps a small, stdlib-only Python core and a thin shell layer. PRs that match that aesthetic are easiest to land.

## Setup

```bash
git clone https://github.com/thelonmower/agentkan
cd agentkan
./tests/run.sh    # runs all tests; needs python3, git, bash, flock
```

## Code conventions

- **Python:** stdlib only. No `requests`, no `click`, no `pydantic`. The CLI is one file (`kanban`) and should stay that way.
- **Shell:** bash with `set -euo pipefail`. POSIX-ish where reasonable. Pass `shellcheck`.
- **No new external runtime deps** without a strong case. The whole point is that this installs on any dev machine without a venv.

## What's in / what's out

**In scope:** anything that makes autonomous Kanban-driven coding agents more reliable, observable, or safer.

**Out of scope:** turning this into a full project-management tool. We're not competing with Jira. The Kanban is the agent's memory, not a team's planning surface.

## How to add a feature

1. Open an issue first if it's non-trivial.
2. Add or update tests in `tests/` (the existing `tests/run.sh` exercises the claim race, tick parallelism, and view server end-to-end).
3. Update the README's command table and the relevant doc page in `docs/`.
4. Keep the diff small. Two small PRs > one large PR.

## What we especially want help with

See [open issues tagged `help-wanted`](https://github.com/thelonmower/agentkan/labels/help-wanted). Current top wishes:

- **Cost tracking** — parse `total_cost_usd` from each `claude -p --output-format json` and aggregate per-project / per-day.
- **GitHub Actions runner** — `kanban tick` triggered on a schedule, no laptop required.
- **TUI mode** — `kanban tui` with a Bubble Tea–style terminal dashboard. (Will require Go in the build chain, so this is a discussion before a PR.)
- **Templates** — `kanban new --template <name>` that seeds the intake with proven answers for common project shapes.

## Reporting bugs

When a card stalls or behaves weirdly:

1. Attach the relevant `logs/<agent>/*.log` (redact API keys if present — there shouldn't be any).
2. Attach the relevant `kanban.json` (redact private project info).
3. Note your `claude --version`, OS, and Python version.

## Code of conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). tl;dr: be a decent human.

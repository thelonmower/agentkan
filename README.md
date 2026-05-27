# agentkan

> **Autonomous Claude Code agents that ship side projects while you sleep.**

You describe what you want. The agent does the work — overnight, weekend, whenever — on a Kanban board you can pop into anytime. Each project gets its own board; cron runs them all.

<p align="center">
  <img src="assets/demo.gif" alt="agentkan demo" width="780">
</p>

```bash
$ kanban new "url shortener in Go"
[10-minute interview happens — vision, agents, card roadmap]

$ kanban view             # opens the dashboard

$ kanban cron             # one cron line, runs everything autonomously
*/10 * * * * ~/.local/bin/kanban tick >> ~/.kanban-hub/logs/tick.log 2>&1
```

That's it. Close the laptop. Come back to a shipped project.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/thelonmower/agentkan/main/install.sh | sh
```

Or clone and run `./install.sh`. Needs `claude` (Claude Code CLI), `python3`, `git`, `flock`.

Mac, Linux, WSL. Native Windows is unsupported (cron, flock).

---

## What this actually is

Most attempts at autonomous coding agents fail because they get *lost* — context fills up, they forget the goal, they wander. The fix isn't a bigger context window. It's externalizing memory into something durable: a Kanban board on disk that survives crashes, reboots, and context overflow.

Each tick is one fresh `claude -p` invocation that:
1. Reads the board
2. Picks the next card it owns
3. Does the work in its own git worktree
4. Commits, updates the board, exits

Power loss, context limits, multi-day work — all non-issues. The board is the memory.

## Multiple projects, one dashboard

Most devs have more than one side project. `agentkan` manages a portfolio:

- **Multiple projects**, each in its own folder, each with its own Kanban board.
- **One cron entry** drives everything. `kanban tick` iterates every project, fires them in the background.
- **One web dashboard** (`kanban view`) shows all projects as tiles, click any tile for the full board. Auto-refreshes.

> **Advanced: parallel agents.** A single project can run multiple agents in parallel (e.g. `ui` + `backend`) on separate git worktrees. It's more powerful, but harder to reason about — start with one agent. See [docs/multi-agent.md](docs/multi-agent.md) when you're ready.

## What makes this different from "just run `claude` in a loop"

| | Naïve loop | This |
|---|---|---|
| Survives context overflow | ❌ session dies | ✅ next tick re-reads board |
| Survives reboot / laptop closed | ❌ | ✅ cron picks back up |
| Multiple projects at once | ❌ | ✅ portfolio view |
| Cards have acceptance criteria | ❌ vibes | ✅ structured intake forces them |
| You can pause one and not another | ❌ | ✅ `kanban pause <project>` |
| Costs are bounded | ❌ unbounded | ✅ `timeout 30m` per tick |

## The intake is the whole game

Most autonomous-agent failures are *spec failures*, not execution failures. So the tool refuses to start work until you've answered the questions:

**Project intake** (on `kanban new`): vision, definition of done, out of scope, subsystem boundaries → agents, per-agent stack and conventions and risk tolerance, cross-agent contracts, card-by-card roadmap with **acceptance_criteria** on every card.

**Per-card intake** (on `kanban add-card`): one-sentence title, owning agent, testable acceptance criteria, dependencies, size check (split if >30 min), out-of-scope-for-this-card.

The runtime agent reads `acceptance_criteria` as its contract. Sharp criteria → clean finish. Vague criteria → drift. The intake forces you to do the spec work up front, when you're fresh.

## What it costs

A typical small side project converges in 40–80 ticks. With a Max plan, that's free. With API, budget roughly $3–$15 for a finished MVP-sized project. The CLI logs cost per tick; aggregated cost tracking is on the roadmap.

## What it isn't

- **Not for production code at a regulated company.** Agents in `acceptEdits` mode have broad bash access. Read the safety section.
- **Not a replacement for code review.** Agents commit to their own branches and never merge to main. You merge.
- **Not magic.** Bad acceptance criteria produce bad output. The intake exists to make you write good ones.
- **Not free.** You'll burn tokens. Watch your bill.

## Quick start

```bash
git clone https://github.com/thelonmower/agentkan
cd agentkan
./install.sh

kanban new "your first project"
# ... interview happens, ~10 min ...

kanban view
# Browser opens to the hub dashboard

kanban cron
# Copy the cron line, paste into `crontab -e`

# Now go to bed.
```

## Commands

| Command | What it does |
|---|---|
| `kanban new <name>` | Create a project + run the intake interview |
| `kanban add-card <project>` | Per-card intake interview |
| `kanban add-agent <project>` | Add a parallel agent to an existing project |
| `kanban view [project]` | Open the hub dashboard |
| `kanban list` | Quick status of all projects |
| `kanban tick` | Run one tick across every project (cron entry) |
| `kanban run <project> <agent>` | Manually trigger one tick for one agent |
| `kanban pause <project>` | Mute cron ticks for a project |
| `kanban resume <project>` | Re-enable |
| `kanban cron` | Print the cron line to install |

## Safety

- Agents run with `claude --permission-mode acceptEdits` and a restricted tool allowlist.
- Every agent works inside its own git worktree on its own branch.
- Agents are instructed to **never push, never merge to main**. You review and merge.
- `timeout 30m` caps every run.
- `kanban pause` instantly stops a project's cron ticks.

For higher-trust setups, the `acceptEdits` permission can be tightened. A Docker-sandbox option that runs each agent in an ephemeral container is on the roadmap.

## Documentation

- [Architecture](docs/architecture.md) — how the locks, worktrees, and ticks fit together
- [Comparison to alternatives](docs/comparison.md)
- [Parallel agents (advanced)](docs/multi-agent.md) — running `ui` + `backend` agents per project

## What's next

See [open issues](https://github.com/thelonmower/agentkan/issues).

## Contributing

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). The codebase is small and stdlib-only on purpose.

## License

MIT. See [LICENSE](LICENSE).

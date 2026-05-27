# Parallel agents per project (advanced)

> Start with one agent per project. Add a second only when the work clearly splits into two non-overlapping lanes — typically `ui` + `backend`. Two agents is roughly 2× the cost and roughly 2× the surface area for things to go sideways.

## The shape

A single project can run multiple agents in parallel. Each agent:

- Has its own role file at `agents/<name>.md` (e.g. `agents/ui.md`).
- Owns its own git **worktree** at `worktrees/<name>/` checked out to its own branch `agent/<name>`.
- Holds its own per-(project, agent) `flock` so two ticks of the same agent can't overlap.
- Only claims cards whose `agent` field matches its name.

Because each agent operates in a separate worktree on a separate branch, they cannot conflict on files. The human merges each agent's branch into `main` when work is done.

## When to use it

Good fit:

- A web app where `ui` (frontend) and `backend` (API/server) are genuinely separable.
- A research project where one agent writes code and a second agent writes prose/docs.
- Anything with a clear seam — different stacks, different file trees, different acceptance criteria.

Bad fit:

- A single tight feature touching one module.
- Anything where the two "agents" would end up editing the same files. Worktrees prevent collisions but you'll get merge friction at integration time.

## Setting it up

```bash
kanban add-agent <project>
# Interview: name, role description, stack, conventions, risk tolerance.
# Creates agents/<name>.md, the branch, the worktree, the role contract.
```

The intake forces you to write the cross-agent contract up front: what's the API surface between them, what does the UI assume about the backend's response shape, etc.

## How the runtime keeps them apart

| Concern | Mechanism |
|---|---|
| Two ticks of the same agent overlapping | Per-agent `flock` (`.lock-<agent>`) |
| Two agents claiming the same card | Cards are partitioned by `agent` field; claim only matches |
| Two agents editing the same file | Separate git worktrees on separate branches |
| Race when both want to update the board | Board-level `flock` (`.board-lock`) held for milliseconds |

See [architecture.md](architecture.md) for the locking diagram and the concurrency proof test.

## Trade-offs vs single-agent

| | Single agent | Parallel agents |
|---|---|---|
| Setup | `kanban new` and go | `kanban new` + one `kanban add-agent` per extra lane |
| Cost | 1× tokens | ~N× tokens (one tick per agent per cycle) |
| Concurrency | None needed | Worktree + lock dance must be set up correctly |
| Debugging | One log stream | One log stream per agent — but the dashboard ties them together |
| Merging | One branch → main | One branch per agent → main, in dependency order |

## Pause one without pausing the others

```bash
kanban pause <project>            # pauses the whole project
# (per-agent pause isn't supported in v0.1 — open an issue if you need it)
```

## Cross-agent dependencies

Cards can declare `depends_on: ["U001"]` — a card that depends on a card owned by another agent will not be claimed until the upstream card is in `done`. This is how you express "backend ships the endpoint before the UI consumes it."

# Architecture

Three locks, two layouts, one idea: the board is the memory.

## The big idea

Most autonomous-coding-agent failures look like context failures. Bigger context windows feel like the answer. They aren't. Even with infinite context, you can't restart from a crashed laptop.

The fix is to *externalize* the memory. The Kanban board is a JSON file on disk. Each tick is a fresh `claude -p` invocation. It reads the board, picks a card, does the work, updates the board, exits. Context overflow becomes irrelevant — the next tick gets a fresh window. Reboots are irrelevant — cron fires anyway.

## File layout

```
~/.kanban-hub/
├── bin/                            # shared scripts copied into each project
├── prompts/                        # the intake + runtime prompts
├── static/                         # hub.html + board.html
├── templates/                      # (reserved for v0.4 templates marketplace)
├── projects/
│   ├── recipe-app/
│   │   ├── CLAUDE.md               # shared project context, all agents read this
│   │   ├── kanban.json             # THE BOARD — source of truth
│   │   ├── agent-prompt.md         # runtime prompt (templated with {{AGENT}}, {{CARD_ID}})
│   │   ├── agents/
│   │   │   ├── ui.md               # UI agent's role definition
│   │   │   └── backend.md          # backend agent's role definition
│   │   ├── claim.sh                # atomic claim helper
│   │   ├── runner.sh               # per-(project,agent) tick
│   │   ├── setup-agents.sh         # creates worktrees
│   │   ├── notify.sh               # desktop notifications
│   │   ├── repo/                   # the actual code lives here as a git repo
│   │   ├── worktrees/
│   │   │   ├── ui/                 # git worktree on branch agent/ui
│   │   │   └── backend/            # git worktree on branch agent/backend
│   │   └── logs/
│   └── side-blog/                  # another project, fully independent
└── logs/                           # hub-level logs (tick.log)
```

## The three locks

1. **Per-(project, agent) lock** (`.lock-<agent>` in each project dir) — prevents two ticks of the same agent on the same project from overlapping. Held by `runner.sh` via `flock -n` (non-blocking; if held, the run exits cleanly).

2. **Board lock** (`.board-lock` in each project dir) — held briefly inside `claim.sh` during the read-modify-write of `kanban.json`. This is the critical section that prevents two parallel claims from grabbing the same card. Held for milliseconds, not the full work duration.

3. **Project status check** (`status: "intake"` vs `"active"` in the board) — soft lock. While a project is in intake (between `kanban new` and the human saying "ship it"), `runner.sh` refuses to do anything.

## The two layouts that prevent collisions

1. **Inter-project isolation**: each project has its own folder, its own git repo, its own worktrees. Two projects literally cannot collide.

2. **Intra-project isolation**: agents within one project use git worktrees on separate branches. The UI agent and backend agent share `repo/.git` but operate in `worktrees/ui/` and `worktrees/backend/` respectively. They can't touch each other's files. Their commits go to `agent/ui` and `agent/backend`. The human merges to `main`.

## The tick lifecycle

```
cron (*/10 * * * *)
  └── kanban tick
        ├── iterate every project (skip if .paused)
        │     └── iterate every agent
        │           └── Popen runner.sh <agent>   ← runs in background
        │
        └── all background runners return; tick exits

runner.sh <agent>  (in background)
  ├── flock .lock-<agent>  ← skip if held
  ├── ./claim.sh <agent>
  │     └── flock .board-lock
  │         ├── read kanban.json
  │         ├── if this agent has in_progress: return that card (resume)
  │         ├── else find first todo card matching agent + deps satisfied
  │         ├── atomically move to in_progress with claimed_by
  │         └── return card ID
  ├── if no card: exit
  ├── template agent-prompt.md with {{AGENT}} and {{CARD_ID}}
  ├── invoke `claude -p` with timeout 30m
  ├── claude reads CLAUDE.md, agents/<agent>.md, kanban.json
  ├── claude does work in worktrees/<agent>/, commits to agent/<agent>
  ├── claude atomically updates kanban.json with outcome
  └── runner.sh fires notify.sh, exits
```

## Why `flock` (not `fcntl` or `lockf`)

Portable across macOS and Linux (with `brew install flock` on macOS), file-descriptor based, automatically released when the process dies. The board lock has a 30-second timeout in `claim.sh` so a crashed claim can't permanently wedge the project.

## Concurrency proof

`tests/run.sh` includes a stress test: 8 concurrent `claim.sh` calls (4 per agent) against a board with one eligible card per agent. The expected outcome is exactly two cards in `in_progress`, one per agent, regardless of OS scheduling. Re-run the test locally any time you change the claim path.

## What lives in `kanban.json`

```jsonc
{
  "project_name": "...",
  "slug": "...",
  "status": "active",                  // or "intake"
  "agents": {
    "ui": {
      "branch": "agent/ui",
      "worktree": "worktrees/ui",
      "role_file": "agents/ui.md",
      "description": "..."
    }
  },
  "columns": {
    "todo":        [ /* cards */ ],
    "in_progress": [ /* cards */ ],
    "blocked":     [ /* cards */ ],
    "done":        [ /* cards */ ]
  },
  "proposed_tasks":  [],               // agent-suggested new cards awaiting approval
  "notes_for_human": []                // surface in the board UI
}
```

A card:

```jsonc
{
  "id": "U001",
  "agent": "ui",
  "title": "Initialize frontend project skeleton",
  "description": "Vite + React + TS, ESLint + Prettier, Vitest.",
  "acceptance_criteria": [             // ← the agent's contract
    "Vite project builds with `npm run build`",
    "`npm test` passes with one smoke test"
  ],
  "priority": 1,
  "depends_on": [],                    // ids of cards that must be in `done` first
  "depends_on_note": "",               // human-readable note (e.g. "must be merged to main")
  "out_of_scope": [],
  "claimed_by": null,                  // set when moved to in_progress
  "started_at": null,                  // ISO 8601 UTC
  "completed_at": null,
  "branch": null,                      // set on done; tells human where commits live
  "progress_notes": null,              // set on partial-progress outcome
  "blocker": null,                     // set on blocked outcome
  "notes": null                        // set on done outcome
}
```

The agent only writes fields it owns: `claimed_by`, `started_at`, `completed_at`, `branch`, `progress_notes`, `blocker`, `notes`. It never touches the top-level `agents` block or other agents' cards.

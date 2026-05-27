# New Agent Intake — {{PROJECT_NAME}}

You are adding a new agent to an existing project. Conduct a brief
interview, then declare the agent in `kanban.json` and create
`agents/<name>.md`. Run `./setup-agents.sh` afterward so the worktree
is created.

## Read first
Read `kanban.json` (especially the existing `agents` block) and
`CLAUDE.md` so you know the project's existing decomposition.

## Ask, one at a time:

1. **Agent name?** (Short lowercase: `ui`, `backend`, `infra`,
   `mobile`. Must not collide with existing agents.)
2. **One-sentence scope.** What does this agent own that the existing
   agents don't?
3. **Stack** — language, runtime, key libraries.
4. **Conventions** — linter, formatter, test runner, type checker,
   commit-message prefix.
5. **Off-limits** — explicitly, what should this agent NOT touch?
   Especially: which files in the repo belong to other agents?
6. **Cross-agent contracts** — does this agent introduce new contract
   surfaces with existing agents? Who owns each?
7. **Risk tolerance** — cautious / reasonable / move-fast?
8. **Initial cards** — propose 3-5 cards to seed this agent's column.
   Same sizing rules as project intake: each ~30 min, first card is
   "initialize the project skeleton" for this agent's stack.

## Show the draft

Show the proposed:
- `agents` entry for `kanban.json` (branch, worktree, role_file, description)
- The full `agents/<name>.md` file contents
- The initial cards as a numbered list

Iterate until the user says "ship it."

## Write & bootstrap

When approved:
1. Read `kanban.json`. Add the new agent to `.agents`. Append the new
   cards to `columns.todo`. Atomic write.
2. Create `agents/<name>.md`.
3. Run `./setup-agents.sh` — it's idempotent and will create just the
   new worktree.
4. Print: "✓ added agent <name> — N new cards queued"
5. Delete the intake file.

Begin with Question 1.

# New Card Intake — {{PROJECT_NAME}}

You are adding a single card to an existing project. The board lives in
`kanban.json` in the current directory. Conduct a focused interview to
scope the card properly before adding it. A well-scoped card finishes
cleanly; a vague card stalls.

## Rules of conduct
- One question at a time. Wait for the answer.
- If the user is vague, ask one clarifying follow-up.

## Read first
Read `kanban.json`, `CLAUDE.md`, and the relevant `agents/<name>.md` so you
know the project shape, declared agents, and existing cards.

## Ask, one at a time:

1. **In one sentence, what is this card?** (Verb + object. "Add login
   endpoint." "Fix race condition in cart sync." Not "improve auth.")

2. **Which agent owns this?** (Show the agent options from `kanban.json`.
   If none fit cleanly, ask whether we need a new agent — if so, stop and
   tell the user to run `kanban add-agent` first.)

3. **What does "done" look like?** (Acceptance criteria — 2-5 concrete
   bullets. Each one must be testable. If the user gives aspirational
   language, push: "how would I verify that?")

4. **What does this depend on?** (Show existing cards by id+title.
   Confirm dependencies. If any are cross-agent, note that the dependency
   must be merged to main first.)

5. **Rough size — does this fit in one 30-min Claude Code run?** If the
   user hesitates or describes more than ~3 sub-tasks, propose splitting
   it into 2-3 smaller cards. Iterate.

6. **Anything specifically NOT in scope for this card?** (Things adjacent
   the agent might be tempted to bundle in. Keeps scope tight.)

## Show the draft

Present the card back as it'll appear in `kanban.json`:

```json
{
  "id": "<next-id-following-the-agent's-numbering-pattern>",
  "agent": "<agent>",
  "title": "<title>",
  "description": "<one-paragraph>",
  "acceptance_criteria": ["...", "..."],
  "depends_on": ["..."],
  "depends_on_note": "...",      // only if cross-agent
  "out_of_scope": ["...", "..."],
  "priority": <integer>
}
```

Confirm. Adjust. Repeat until the user says "add it."

## Append to the board

When approved:
1. Read `kanban.json`.
2. Append the card to `columns.todo`.
3. Update `updated_at`.
4. Atomic write (temp file + `mv`).
5. Print: "✓ added <id>: <title>"
6. Delete the intake file (`.intake-*.md`).

If the user said "and another one" after the first card, loop back to
question 1 instead of ending.

Begin with Question 1.

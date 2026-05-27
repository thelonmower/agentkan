# Comparison to alternatives

Honest comparisons. If you're doing what you actually need with something else, use that.

## vs. just running `claude` in a loop with `--resume`

This is the natural first thing to try. It works for one tightly-scoped task. It breaks down when:

- The task spans more context than fits in one session
- You walk away from the laptop and the loop crashes
- You want multiple tasks running in parallel
- You want to actually see what's happening

The Kanban-board-as-memory model fixes all four. Each tick is a fresh session that reads state from disk. No session sprawl, no context creep, no "where was I."

## vs. claude-flow

[claude-flow](https://github.com/ruvnet/claude-flow) is more sophisticated — it does swarm orchestration, hive-mind coordination, neural memory. If you want a research-grade multi-agent system with extensive coordination, use claude-flow.

This project is the opposite end of the spectrum: **minimal, durable, boring**. One Python file plus shell scripts. No daemons running between ticks. The "swarm" coordination is just `flock` and a JSON file. The trade-off is less sophistication for more reliability and one less thing to debug at 2am.

## vs. GitHub Copilot Workspace / Cursor agents / Devin / Replit agents

Those are integrated IDE experiences with their own infrastructure. They're great inside their environments. This is for when you want:

- Your own local files, your own git, your own machine
- Multiple projects running in parallel that you can pop in and out of
- The agent loop to keep working when you close the IDE
- No vendor lock-in — it's just Claude Code, your shell, and a JSON file

## vs. plain GitHub Issues + manual Claude Code sessions

This is what most devs do today. It works fine for projects where you're actively driving every session. It doesn't scale to:

- Letting work happen while you sleep
- Running multiple projects in parallel
- Having the agent self-manage which task is next based on dependencies

The intake interview in this tool is essentially "writing very good GitHub issues, but the agent then picks them up automatically." If you already write excellent issues and don't mind manually shepherding sessions, you don't need this.

## vs. CI/CD bots that fix PRs

Tools like Renovate, Dependabot, or GitHub's auto-fixer are focused, well-bounded agents that do one narrow job (bump deps, fix vulnerabilities). They're great. They don't build features.

This tool builds features. It's a different shape of automation.

## When this project is the wrong choice

- You're shipping production code under a regulatory regime
- You need every commit reviewed by a human before it lands on the agent's *own* branch (this tool already enforces a human merge to `main`, but the agent commits freely on its branch)
- You don't want to spend money on tokens
- You prefer driving Claude Code interactively because you like the conversation
- Your projects are tightly bounded single sessions — no need for persistence

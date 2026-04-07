# codearmy

**Orchestrator-native long-running code and research campaigns for Claude Code.**

codearmy is a [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) that lets Claude orchestrate multi-phase engineering tasks — planning, reviewing, executing, and verifying — using a persistent **campaign repo** as the shared source of truth. It is designed for tasks that span hours to days, require multiple agents working in parallel, and need to survive interruptions and restarts.

---

## How it works

codearmy uses five roles, each run in its own agent invocation:

| Role | Model | Responsibility |
|------|-------|---------------|
| **Orchestrator** | Claude Sonnet 4.6 (you) | Coordinates all agents, maintains progress, talks to the user |
| **Planner** | Claude Opus 4.6 | Decomposes the goal into phases and tasks |
| **Planner_Reviewer** | Codex xhigh | Audits the plan before execution starts |
| **Executor** | Codex medium | Implements each task, writes results to the campaign repo |
| **Reviewer** | Claude Sonnet 4.6 | Reviews each task's output against acceptance criteria |

Agents communicate via a **campaign repo** — a local directory of markdown files — not by passing large messages to each other. This keeps every agent's context small and makes the whole campaign resumable after interruption.

```
campaign-repo/
├── campaign.md          # Goal, constraints, current phase, status
├── glossary.md          # Shared terminology for all agents
├── plan.md              # Current execution plan (Planner output)
├── plans/reviews/       # Plan review records (PR001.md, PR002.md…)
├── phases/
│   └── P01/
│       ├── phase.md
│       └── tasks/
│           └── T001/
│               ├── task.md      # Task metadata and acceptance criteria
│               ├── progress.md  # Executor execution record
│               ├── results/     # Actual artifacts (patches, test output…)
│               └── reviews/     # Reviewer records (R001.md…)
├── checkpoints/         # Phase-completion checkpoints for recovery
└── reports/
    ├── live-report.md   # Real-time progress maintained by Orchestrator
    └── final-report.md  # Final acceptance report
```

---

## Workflow

```
User describes goal
  └─► Orchestrator clarifies requirements
        └─► Planner writes plan.md + phases/
              └─► Planner_Reviewer audits (approve / rework / needs_human)
                    └─► Executor runs tasks in parallel (per phase)
                          └─► Reviewer checks each task
                                └─► Planner does final goal acceptance
```

Every phase ends with a checkpoint. If the session is interrupted, the Orchestrator reads `reports/live-report.md` and each `task.md` to resume from where it left off.

---

## Installation

### As a Claude Code skill

Copy or symlink this repo into your skills directory:

```bash
# Copy
cp -r /path/to/codearmy ~/.claude/skills/alice-code-army

# Or symlink
ln -s /path/to/codearmy ~/.claude/skills/alice-code-army
```

Then invoke it in Claude Code:

```
/alice-code-army <your campaign goal>
```

### With Alice bot

If you are running [Alice](https://github.com/Alice-space/alice), install it as a bundled skill:

```bash
cp -r /path/to/codearmy ~/.alice/skills/alice-code-army
```

Trigger it with a `#work` message in your Feishu conversation.

---

## Requirements

- [Claude Code](https://claude.ai/code) (CLI or IDE extension)
- [Codex](https://github.com/openai/codex) CLI (`codex` must be on your PATH)
- Claude API access (Sonnet 4.6 for Orchestrator/Reviewer, Opus 4.6 for Planner)

---

## Key design decisions

**Orchestrator does not implement.** Its context is reserved for coordination and high-level decisions. All implementation goes to Executor subagents.

**Campaign repo is the message bus.** Agents write to the repo; the Orchestrator reads the repo to track progress. No large message passing between agents.

**Every task has explicit acceptance criteria.** The Reviewer checks each one and returns `approve` or `rework`. The Orchestrator applies the verdict.

**Checkpoints after every phase.** A single file in `checkpoints/` is enough to resume after a restart.

**Plan is reviewed before execution.** The Planner_Reviewer prevents wasted Executor cycles on a bad plan.

---

## Sandbox note (Codex)

Codex runs in `workspace-write` mode by default, which only allows writes to the current working directory and `TMPDIR`. If the Orchestrator launches Codex from Alice's workspace directory (`~/.alice/bots/<bot>/workspace`) and the target repo is elsewhere (e.g. `~/alice`), file writes will fail with "read-only filesystem".

**Fix:** The Executor prompt always starts with `cd <target_repo_path>`. See `SKILL.md` for full details.

---

## Repository structure

```
codearmy/
├── SKILL.md                    # Full skill definition (loaded by Claude Code)
├── agents/
│   └── openai.yaml             # Agent interface descriptor
└── templates/
    └── campaign-repo/          # Starter template for a new campaign repo
```

---

## Related

- [Alice](https://github.com/Alice-space/alice) — the Feishu bot runtime that hosts this skill
- [Claude Code](https://claude.ai/code) — the AI coding environment this skill targets

---

## License

MIT

# codearmy

**Alice Code Army** — Orchestrator-native long-running code/research collaboration skill for Claude Code.

> This skill has been extracted from the [Alice](https://github.com/Alice-space/alice) repository into its own standalone repo for easier distribution and installation.

## What is codearmy?

codearmy is a Claude Code skill that lets Claude orchestrate long-running, multi-phase, multi-agent engineering campaigns. It implements a full Plan → Review → Execute → Review workflow with:

- **Orchestrator** (Claude Sonnet 4.6) — coordinates all agents, maintains progress state, communicates with user
- **Planner** (Claude Opus 4.6) — decomposes goals into phases and tasks
- **Planner_Reviewer** (Codex xhigh) — audits plans before execution begins
- **Executor** (Codex medium) — implements each task, writes results to campaign repo
- **Reviewer** (Claude Sonnet 4.6) — reviews each task's output against acceptance criteria

All agents communicate via a shared **campaign repo** (a local directory), not by passing large messages between each other. This makes the system resumable after interruption.

## When to use

- Multi-phase engineering tasks that take hours to days
- Tasks requiring Plan → Review → Execute → Review workflow
- Parallel task execution across multiple repos or subsystems
- Long-running research with checkpointing and disaster recovery

## Installation

### Via Alice bot

If you're running Alice, codearmy can be installed as a skill. Copy the contents of this repo into your Alice skills directory:

```bash
cp -r /path/to/codearmy ~/.alice/skills/alice-code-army
```

Or link it:

```bash
ln -s /path/to/codearmy ~/.agents/skills/alice-code-army
```

### Standalone Claude Code

Copy the `SKILL.md` and supporting files into your Claude Code skills directory:

```bash
cp -r /path/to/codearmy ~/.claude/skills/alice-code-army
```

## Usage

Invoke via the alice-code-army skill in Claude Code:

```
/alice-code-army <your campaign goal>
```

Or in Alice bot with `#work` trigger, describe your long-running task.

## Campaign Repo Structure

```
<campaign-repo>/
├── campaign.md          # Overall goal, constraints, current phase
├── glossary.md          # Shared terminology for all agents
├── plan.md              # Current execution plan (Planner output)
├── plans/reviews/       # Plan review records (PR001.md, PR002.md...)
├── phases/
│   └── P01/
│       ├── phase.md
│       └── tasks/
│           └── T001/
│               ├── task.md      # Task metadata and acceptance criteria
│               ├── progress.md  # Executor execution record
│               ├── results/     # Actual artifacts
│               └── reviews/     # Reviewer records
├── checkpoints/         # Phase completion checkpoints for recovery
└── reports/
    ├── live-report.md   # Real-time progress maintained by Orchestrator
    └── final-report.md  # Final acceptance report
```

## Key Design Principles

1. **Orchestrator doesn't do implementation** — it only coordinates
2. **Campaign repo is the shared message bus** — all agents write to it, not to each other
3. **Every task has explicit acceptance criteria** — Reviewer checks each one
4. **Checkpoint after every phase** — enables disaster recovery
5. **Plan goes through Review before execution** — prevents wasted effort

## Repository

- Source: https://github.com/Alice-space/codearmy
- Alice bot: https://github.com/Alice-space/alice

## License

MIT

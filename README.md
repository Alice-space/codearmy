# codearmy

**Orchestrator-native long-running code and research campaigns for Claude Code and Codex runtimes.**

codearmy is a skill bundle for long-running multi-phase engineering tasks — planning, reviewing, executing, and verifying — using a persistent **campaign repo** as the shared source of truth. It is designed to run under either Claude Code or Codex-family hosts, survive interruptions, and keep role coordination outside the main orchestrator context. The role models stay fixed; only the invocation route changes with the host runtime.

---

## How it works

codearmy uses five roles, each run in its own agent invocation. Role models are fixed; provider routing is runtime-dependent:

| Role | Route | Responsibility |
|------|----------------|---------------|
| **Orchestrator** | Current session (you) | Coordinates all agents, maintains progress, talks to the user |
| **Planner** | Claude `opus[1m]`, routed by host runtime | Decomposes the goal into phases and tasks |
| **Planner_Reviewer** | Codex `gpt-5.4 xhigh`, routed by host runtime | Audits the plan before execution starts |
| **Executor** | Codex `gpt-5.4 high`, routed by host runtime | Implements each task, writes results to the campaign repo |
| **Reviewer** | Claude `sonnet`, routed by host runtime | Reviews each task's output against acceptance criteria |

Routing matrix:

| Host runtime | Claude-family model | CodeX-family model |
|------|----------------------|--------------------|
| **Claude Code** | native `spawn_agent` / subagent | installed CodeX plugin |
| **Codex** | Claude plugin such as `claudeagent` | native `spawn_agent` |

In Codex, native `spawn_agent` is not a durability layer. Use it only for synchronous stages where the current Orchestrator session will stay alive and `wait_agent` until the child reaches a terminal state. If an Executor task may outlive the current parent rollout, persist state to the campaign repo first and hand execution off to runtime `campaign_dispatch:*` / `campaign_wake:*` automation or a scheduler wake-up instead of fire-and-forget `spawn_agent`.

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
│               ├── progress.md  # Executor progress record
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
cp -r /path/to/codearmy <claude-skills-dir>/codearmy

# Or symlink
ln -s /path/to/codearmy <claude-skills-dir>/codearmy
```

Then invoke it in Claude Code:

```
/codearmy <your campaign goal>
```

When this skill is running inside Claude Code:

- `Planner=Claude opus[1m]` and `Reviewer=Claude sonnet` should use native `spawn_agent` / subagents.
- `Planner_Reviewer=Codex gpt-5.4 xhigh` and `Executor=Codex gpt-5.4 high` should use the CodeX plugin installed in that Claude Code environment.

### With Alice bot

If you are running [Alice](https://github.com/Alice-space/alice), install it as a bundled skill:

```bash
cp -r /path/to/codearmy <alice-skills-dir>/codearmy
```

Trigger it with a `#work` message in your Feishu conversation.

When this skill is running inside Codex or a Codex-hosted Alice runtime:

- `Planner_Reviewer=Codex gpt-5.4 xhigh` and `Executor=Codex gpt-5.4 high` should use native `spawn_agent` only when the current parent session will remain alive and explicitly `wait_agent` for completion.
- If the Executor may run longer than the current parent rollout can stay alive, do not treat `spawn_agent` as fire-and-forget; persist state to the campaign repo and resume through runtime `campaign_dispatch:*` / `campaign_wake:*` automation or a scheduler wake-up.
- `Planner=Claude opus[1m]` and `Reviewer=Claude sonnet` should use the Claude plugin, for example the bundled `claudeagent` helper described below.

### Campaign repo bootstrap

From this repo checkout, use the helper script instead of manually copying the template:

```bash
./scripts/init-campaign-repo.sh \
  /path/to/campaigns/demo \
  --campaign-id demo \
  --title "Demo campaign" \
  --objective "Describe the target end state"
```

If the target directory already exists and you intentionally want to replace it, re-run the same command with `--force`.

---

## Requirements

- A host runtime: [Claude Code](https://claude.ai/code) or [Codex](https://github.com/openai/codex)
- For Codex-hosted runs that need Claude-family models: Node.js plus the ClaudeAgent plugin runtime for `scripts/claude-plugin.sh`
- For Claude Code-hosted runs that need CodeX-family models: a CodeX plugin installed in that Claude Code environment
- For Codex-hosted Executor work, the Codex runtime and tooling must be available

---

## Key design decisions

**Orchestrator does not implement.** Its context is reserved for coordination and high-level decisions. All implementation goes to subagents.

**While subagents are running, the Orchestrator only supervises.** It may watch status, update the live report, react to `blocked` states, and handle user input. It must not jump in to do the subagent's work, and it must not exit the campaign just because a subagent is still running.

**Campaign repo is the message bus.** Agents write to the repo; the Orchestrator reads the repo to track progress. No large message passing between agents.

**Models are fixed; routing is not.** `Planner=Claude opus[1m]`, `Planner_Reviewer=Codex gpt-5.4 xhigh`, `Executor=Codex gpt-5.4 high`, `Reviewer=Claude sonnet`; only the host runtime decides whether that fixed role call goes through native `spawn_agent` or the opposite-side plugin. In Codex, native `spawn_agent` still requires the Orchestrator to remain alive and `wait_agent`; it is not a durable background worker by itself.

**Every task has explicit acceptance criteria.** The Reviewer checks each one and returns `approve` or `rework`. The Orchestrator applies the verdict.

**Checkpoints after every phase.** A single file in `checkpoints/` is enough to resume after a restart.

**Plan is reviewed before execution.** The Planner_Reviewer prevents wasted Executor cycles on a bad plan.

---

## Sandbox note (Codex)

Codex runs in `workspace-write` mode by default, which only allows writes to the current working directory and `TMPDIR`. If the Orchestrator launches Codex from one directory while the campaign repo or target repo lives elsewhere, file writes can fail with "read-only filesystem".

**Fix:** Run Codex with `-C <target_repo_path>` and `--add-dir <campaign_repo_path>`. See `SKILL.md` for full details.

---

## Repository structure

```
codearmy/
├── SKILL.md                    # Full skill definition
├── agents/
│   └── openai.yaml             # Agent interface descriptor
├── scripts/
│   ├── claude-plugin.sh        # Codex-side ClaudeAgent wrapper with plugin auto-discovery
│   └── init-campaign-repo.sh   # Campaign repo bootstrap helper
└── templates/
    └── campaign-repo/          # Starter template for a new campaign repo
```

---

## Related

- [Alice](https://github.com/Alice-space/alice) — the Feishu bot runtime that hosts this skill
- [Claude Code](https://claude.ai/code) — one supported host runtime
- [Codex](https://github.com/openai/codex) — the other supported host runtime

---

## License

MIT

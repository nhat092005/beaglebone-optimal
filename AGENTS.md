# Agent Instructions

## Repo Purpose

`beaglebone-optimal` is a self-learning BSP workspace for BeagleBone Black /
TI AM335x. The repo is currently centered on:

- Docker-based builder workflow
- storage-backed Yocto builds
- baseline image generation
- early board bring-up and SD flashing

Do not assume this repo already contains a full BSP customization stack. Start
from the current workflow and extend only what the task requires.

## Orient Quickly

Read in this order:

1. `~/.codex/AGENTS.md` and `AGENTS.md` for agent workflow.
2. [`README.md`](README.md) for repo purpose and major docs
3. [`Makefile`](Makefile) for the public command surface
4. `local.mk` if it exists, otherwise [`local.mk.example`](local.mk.example),
   for local machine inputs
5. [`compose.yaml`](compose.yaml) and [`docker/Dockerfile`](docker/Dockerfile)
   for builder runtime and image contract
6. [`docs/_RUNBOOK_EN.md`](docs/_RUNBOOK_EN.md) or
   [`docs/_RUNBOOK_VN.md`](docs/_RUNBOOK_VN.md) for operational workflow

If the task touches a specific command, read the script that implements it
before making assumptions.

## Source Of Truth

Prefer repo truth in this order:

1. code and config actually executed
2. `Makefile` as the public CLI contract
3. implementation scripts under `scripts/`
4. builder runtime files: `compose.yaml`, `docker/Dockerfile`
5. docs and examples

If docs disagree with code, trust code first, then update docs to match.

## Repo Map

- `Makefile`: public entrypoints for builders, Yocto workflow, and host-side
  utilities
- `scripts/`: implementation helpers behind `Makefile` targets
- `docker/`: builder image definition
- `docs/`: runbooks and quality guidance, not the primary behavior source
- `yocto/conf/`: example config inputs copied into the external Yocto build dir
- `assets/`: demo media only
- `tmp/`: task-specific notes, roadmaps, or evidence; useful context, but not a
  stable contract unless the task explicitly says so

## Working Model

- Generated data belongs under `PROJECT_STORAGE_ROOT`, not in the source tree.
- Some commands run in the builder container, others run on the host. Check
  `Makefile` and the runbook before assuming where a command executes.
- Treat `local.mk` as machine-local input. Do not commit it.
- Keep `AGENTS.md` high-level. Put procedural detail in the runbook or
  task-specific docs, not here.

## Task Guidance

- For workflow questions, start from `Makefile` and the runbook.
- For environment questions, inspect `local.mk` or `local.mk.example`.
- For behavior changes, read the touched script or config directly instead of
  inferring behavior from docs.
- For Yocto/OpenEmbedded recipe patches, prefer generating `.patch` files from
  committed source changes with `devtool finish` or `git format-patch` rather
  than hand-writing patch hunks. Only hand-write a patch when the change is
  intentionally tiny and there is no practical source tree to export from.
- When a task references board bring-up or flashing, verify whether the step is
  host-side or builder-side before acting.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:7510c1e2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **beaglebone-optimal** (174 symbols, 176 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/beaglebone-optimal/context` | Codebase overview, check index freshness |
| `gitnexus://repo/beaglebone-optimal/clusters` | All functional areas |
| `gitnexus://repo/beaglebone-optimal/processes` | All execution flows |
| `gitnexus://repo/beaglebone-optimal/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

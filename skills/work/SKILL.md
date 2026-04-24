---
name: work
description: Use whenever the user wants work executed on the todo backlog — running tasks, building features, implementing what has already been modeled. Triggers on phrases like "start working", "execute the todo", "work on it", "build it", "implement the backlog", "let's go", "run the workers", "pick up where you left off", "ship what's ready". Spawns parallel worker sub-agents that resolve task dependencies and claim ready tasks from `contexts/*/todo/`. New tasks promoted to todo during the run are picked up automatically as they become ready. Does not do modeling — only executes already-refined tasks.
---

# Work — Parallel Dependency-Aware Worker Loop

The `work` skill turns refined `todo/` tasks into real code and real decisions. It is a loop, not a one-shot: it keeps going until todo is empty (or the user stops it), and it picks up tasks added mid-run.

**The orchestrator (you) never writes code.** You coordinate: scan, build the DAG, dispatch workers, commit, log. Keeping you lean prevents context exhaustion across long batches. All coding work is delegated to subagents.

## Phase 1: Recovery check

Before anything else, look at `contexts/*/doing/`:
- **0 tasks** → proceed to Phase 2.
- **1 task** → a previous session was interrupted. Resume it sequentially as the first task of this session, *before* starting any parallel dispatch.
- **2+ tasks** → a previous parallel session was interrupted. Ask the user: "Resume all in parallel", "Resume one at a time", or "Abandon — move them back to todo". Do not guess.

## Phase 2: Build the dependency graph

1. Read `.agenthoff/vision.md` and `.agenthoff/context-map.md` for orientation.
2. Scan `.agenthoff/contexts/*/todo/` and `.agenthoff/contexts/*/doing/`.
3. For every todo task, read `depends_on`. A task is *ready* if every id in `depends_on` is in `done/` (or doesn't exist — treat missing as satisfied, but warn the user).
4. **Detect cycles.** If the graph has a cycle, stop and surface the cycle to the user. Do not "just pick one".
5. Briefly tell the user what you found: "X tasks ready across N contexts, Y tasks blocked on Z."

## Phase 3: Conflict detection before batch dispatch

Two parallel workers touching the same file is the most common cause of merge pain. Defend against it:

1. For each ready task, scan its `What`, `Acceptance criteria`, and `Notes` sections for file paths, directory references, and shared resources (BC READMEs, ADRs, shared modules).
2. If two ready tasks reference the same file or directory, **demote the higher-id task to the next batch** — don't dispatch it in the current wave.
3. Tasks targeting the same BC's README count as a conflict (only one worker updates the BC memory per batch).
4. **Cap the batch at MAX_PARALLEL = 3** unless the user asked otherwise. Pick the lowest-numbered unblocked, non-conflicting tasks.

## Phase 4: Batch dispatch

For each dispatch wave:

1. **Move all selected task files** from `todo/` to `doing/` (the orchestrator does this *before* spawning subagents — prevents workers racing for the same file).

2. **Log "Batch started"** to `.agenthoff/knowledge/protocol.md` (prepend — see "Protocol logging" section below).

3. **Spawn one subagent per task** using the Agent tool with `subagent_type: "worker"`. Launch all subagents in **one message** (parallel tool calls). Use the Subagent Prompt Template below.

4. **Wait for all subagents to complete.** As each returns:
   - Parse its strict return format (see template).
   - For `RESULT: SUCCESS`:
     - **Commit the result** (see "Git authority" section).
     - Log "Task completed" to protocol.md.
   - For `RESULT: BOUNCED`: the worker moved the task back to `backlog/` because it was under-refined. Log "Task bounced" to protocol.md. Do not commit — the worker made no changes.
   - For `RESULT: FAILED`: log "Task failed" to protocol.md with the error. Leave the task in `doing/` so it doesn't silently retry. Tell the user at the end.
   - One failure does not block the batch — the other subagents continue and are processed normally.

5. **After the batch completes**, return to Phase 2 — re-scan. New tasks may have been promoted to todo (via parallel `model` invocations) or new dependencies may have unblocked.

## Git authority (orchestrator only)

Git is owned by `work`, not by workers. Workers only move files and write content. This is load-bearing for parallel safety — two workers committing concurrently can race.

After a worker returns `RESULT: SUCCESS`:

1. `git status` to see what changed.
2. `git add` — the files from `FILE_LIST` plus the moved task file, the updated BC README (if the worker reports `BC_README_UPDATED: yes`), and any ADRs listed in `ADRS_WRITTEN`. **Never `git add -A`** — it sweeps in unrelated changes (user's in-progress work, or a parallel sibling worker's files).
3. Commit with message:
   ```
   <type>(<bc>): <summary> [<task-id>]
   ```
   where `<type>` comes from the task's frontmatter (feature / bug / refactor / chore / spike / decision), `<bc>` is the bounded context, `<task-id>` is the task id. Example:
   `feature(books): add ReadingSession concept to Book aggregate [books-001]`
4. Capture the commit SHA.
5. Update the task file's frontmatter with `commit: <sha>` (you do this — the worker already set status=done and moved the file, you add the SHA the worker didn't have).

One task = one commit. Commit after each worker returns, not in a batch — that way if the next worker fails we haven't bundled it with a completed one.

If the project isn't a git repo, skip commits silently and note it in the end-of-run summary.

## Protocol logging

`.agenthoff/knowledge/protocol.md` is the project's chronological diary. Every `work` event prepends a new entry. Keep entries terse — the diff carries the detail.

If `protocol.md` doesn't exist, create it with:
```markdown
# Protocol

Chronological log of everything that happens in this project.
Newest entries on top.

---
```

Then every entry is prepended right after the `---` on line 4.

Entry formats:

```markdown
## YYYY-MM-DD HH:MM -- Batch started: [task-id-1, task-id-2, ...]

**Type:** Work / Batch start
**Tasks:** task-id-1 - [title], task-id-2 - [title]
**Parallel:** yes / no (N workers)

---

## YYYY-MM-DD HH:MM -- Task completed: <task-id> - [title]

**Type:** Work / Task completion
**Task:** <task-id> - [title]
**Summary:** [worker's 1-line SUMMARY]
**Commit:** <short-sha>
**Files changed:** N
**ADRs written:** [ids or "none"]

---

## YYYY-MM-DD HH:MM -- Task bounced: <task-id> - [title]

**Type:** Work / Task bounced
**Task:** <task-id> - [title]
**Reason:** [worker's REASON]
**Moved to:** backlog

---

## YYYY-MM-DD HH:MM -- Task failed: <task-id> - [title]

**Type:** Work / Task failure
**Task:** <task-id> - [title]
**Error:** [worker's ERROR]
**Left in:** doing

---
```

## Subagent Prompt Template

Spawn each worker with `Agent(subagent_type: "worker", prompt: <the-below>)`. Fill the placeholders.

```
You are a worker agent executing one refined task. Stay strictly within its scope.

## Your task
Task file (currently in doing/): <ABSOLUTE-PATH>
Bounded context: <BC-NAME>
BC README: <ABSOLUTE-PATH-TO-BC-README>

## Project context (read only if you need them)
- .agenthoff/vision.md
- .agenthoff/context-map.md (if exists)
- .agenthoff/knowledge/decisions/ (ADRs)
- .agenthoff/knowledge/research/ (research reports)

## Rules — CRITICAL
1. Do NOT run `git add`, `git commit`, or any git write operation. The orchestrator owns git.
2. Do NOT modify `.agenthoff/knowledge/protocol.md`. The orchestrator owns protocol logging.
3. Do NOT touch any task file other than the one you were assigned.
4. Do NOT modify other BCs' READMEs. Only the BC your task belongs to.
5. DO write code, run tests, update YOUR BC's README, write ADRs for decisions you make.
6. DO move your task file from doing/ to done/ when acceptance criteria are met, and update its frontmatter (status: done, completed: YYYY-MM-DD).
7. If the task is under-refined (no concrete acceptance criteria, unclear scope, unmet dependencies, insufficient BC language), MOVE IT BACK TO backlog/ with a `## Worker note` explaining what's missing, and return RESULT: BOUNCED. This is correct behavior, not a failure.

## Context hygiene — IMPORTANT
Your context window is finite. Respect it:
- Read only what you need. Use targeted reads (offset/limit) on large files. Don't read a whole file for a few lines.
- Don't echo file contents back in your output — work with them silently.
- Keep tool output concise (use head/tail, --quiet flags).
- Don't re-read files you've already read unless they've changed.
- Don't restate the task file or the BC README verbatim — the orchestrator already has them.

## Return format — STRICT
When done, return ONLY the following, nothing else. No prose, no preamble, no "here's what I did".

RESULT: SUCCESS
TASK_ID: <id>
SUMMARY: <one or two sentences, domain-language>
FILES_CHANGED: <integer>
FILE_LIST: <comma-separated absolute paths of all files you created or modified, EXCLUDING the moved task file>
BC_README_UPDATED: yes | no
ADRS_WRITTEN: <comma-separated filenames under .agenthoff/knowledge/decisions/, or "none">
NEW_BACKLOG_ITEMS: <comma-separated task ids created in a backlog/ during your work, or "none">

For a bounce, return:
RESULT: BOUNCED
TASK_ID: <id>
REASON: <one or two sentences on what was missing>

For a failure, return:
RESULT: FAILED
TASK_ID: <id>
ERROR: <where and why it went wrong, one or two sentences>
```

## End-of-run reporting

When `todo/` is empty and all `doing/` is resolved (or the user interrupts):

1. Summarize in plain prose: tasks completed, tasks bounced (and why), tasks failed (and why), ADRs written, new backlog items created, total commits made.
2. Surface anything that surprised you mid-run: cycles detected, dependency gaps, recovered sessions.
3. Prepend a final protocol entry:
   ```markdown
   ## YYYY-MM-DD HH:MM -- Work session ended
   
   **Type:** Work / Session end
   **Completed:** N
   **Bounced:** M
   **Failed:** K
   **Commits:** <count>
   
   ---
   ```

## Do not model in work

If a worker realizes mid-task that the scope is actually under-refined, it bounces to backlog — it does not try to refine the task itself. Refinement is the `model` skill's job, with the user in the loop. Workers executing under-specified tasks produce plausible-looking but wrong output — that's the worst possible outcome.

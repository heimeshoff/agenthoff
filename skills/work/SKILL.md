---
name: work
description: Use whenever the user wants work executed on the todo backlog — running tasks, building features, implementing what has already been modeled. Triggers on phrases like "start working", "execute the todo", "work on it", "build it", "implement the backlog", "let's go", "run the workers", "pick up where you left off", "ship what's ready". Spawns parallel worker sub-agents that resolve task dependencies and claim ready tasks from `contexts/*/todo/`. New tasks promoted to todo during the run are picked up automatically as they become ready. Does not do modeling — only executes already-refined tasks.
---

# Work — Parallel Dependency-Aware Worker Loop

The `work` skill turns refined `todo/` tasks into real code and real decisions. It is a loop, not a one-shot: it keeps going until todo is empty (or the user stops it), and it picks up tasks added mid-run.

## Before spawning workers

1. Read `.agenthoff/vision.md` and `.agenthoff/context-map.md` for orientation.
2. Scan `.agenthoff/contexts/*/todo/` and `.agenthoff/contexts/*/doing/`.
3. **Build the dependency graph.** For every todo task, read `depends_on`. A task is *ready* if every id in `depends_on` is in `done/` (or doesn't exist — treat missing as satisfied, but warn the user).
4. **Detect cycles.** If the graph has a cycle, stop and surface the cycle to the user. Do not "just pick one".
5. Briefly tell the user what you found: "X tasks ready across N contexts, Y tasks blocked on Z."

## Spawning workers

For each ready task, launch a background sub-agent running the `worker` agent via the **orchestrator**. Run them in parallel — the Agent tool supports multiple concurrent tool calls in a single message. Respect a reasonable cap (default: 4 concurrent workers) so the filesystem and the user's attention don't saturate. If the user wants a different cap, honor it.

Each worker gets:
- The full path to its task file
- The BC's README
- The vision.md and context-map.md
- The knowledge/ directory path (decisions and research it can consult)
- Instructions to claim → execute → complete (see worker agent)

## The loop

After spawning the initial wave:
1. When any worker finishes (success or failure), re-read the DAG.
2. Newly-ready tasks: spawn workers for them, up to the cap.
3. Newly-promoted tasks (user ran `model` with PROMOTE while workers were running): also pick them up.
4. Failed tasks: move the task file back to `todo/` (or to a `blocked/` dir if the worker explicitly marked it blocked) and surface the reason. Do not silently retry — the user needs to know.
5. Continue until todo is empty and all doing is resolved.

## Claim discipline

A task is *claimed* when its file moves from `todo/` to `doing/`. This must happen atomically — the worker's first action. Two workers must never claim the same task. If the parallel spawning could cause a collision, assign each worker a specific task id upfront (do not let them self-select from a shared pool).

## Finishing a task

A worker completes by:
1. Making the code/content changes the task describes
2. Updating the task file's `status` to `done` and moving it from `doing/` to `done/`
3. Writing ADRs to `knowledge/decisions/` for any decisions made during the work
4. If new work was discovered (bugs found, follow-ups needed), creating tasks in `backlog/` — do not directly put things in todo, let the user refine

## Do not model in work

If a worker realizes the task is actually under-refined (ambiguous, missing acceptance criteria, unclear scope), it **moves the task back to backlog** with a note explaining what's missing, and the work loop continues with other tasks. It does not try to refine the task itself. Refinement is the `model` skill's job, with the user in the loop.

This is deliberate: the user's involvement in modeling is load-bearing. Workers executing under-specified tasks produces plausible-looking but wrong output.

## Decisions during work

When a worker (or a specialist the worker consults) makes a decision that deserves to be remembered — a library choice, a pattern choice, a trade-off between options — write an ADR. Brief is fine: context, decision, consequences, links back to the task. The goal is that future workers and future sessions can find out why something is the way it is.

## Reporting

At the end (or on user interrupt):
- Summarize: tasks completed, tasks still in doing, tasks that failed and why, new tasks added to backlog, ADRs written
- Do not re-describe every code change — the diff speaks for itself
- Flag anything that surprised you mid-run (cycles, tasks that turned out wrong, dependency gaps)

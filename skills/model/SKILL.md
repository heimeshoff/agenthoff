---
name: model
description: Use whenever the user wants to capture an idea, bug, feature request, refinement, or change to an existing bounded context — anything from "the button should be green" to "we need a whole new subscription subsystem". Also use when the user wants to refine existing backlog items or promote refined items to ready-to-work. Triggers on phrases like "I have an idea", "let's model this", "capture this", "add this to the backlog", "refine the auth backlog", "promote X to todo", "we should also", "what if we added", "there's a bug", "change the color of", "the domain needs to handle". Creates task markdown files in the appropriate bounded context with the right status, and can spawn deeper modeling sessions via the orchestrator.
---

# Model — Capture, Refine, Promote

The `model` skill is the main entry point for the user's stream of ideas. Every thought — from a one-line bug to a cross-context architectural shift — enters the system here and ends up as a task file in a bounded context.

## The three modes

Decide which mode applies based on what the user said and the current state of `.agenthoff/`:

| Mode | When | What it does |
|---|---|---|
| **CAPTURE** | User is describing something new | Turns the idea into one or more task files. Places them in `backlog/` if under-refined, or `todo/` if the idea is already concrete enough to work on. |
| **REFINE** | User wants to work through an existing backlog item, OR the user invoked model with no new idea and backlog items exist | Picks a backlog task, deepens it via the orchestrator, splits it if needed, updates acceptance criteria and dependencies. May move to `todo/` if it becomes ready. |
| **PROMOTE** | User explicitly wants a task ready for work | Moves a task from `backlog/` to `todo/`, verifying it has enough detail to be picked up by a worker. |

### Disambiguating intent

- If the user gives a concrete idea ("add dark mode") → CAPTURE
- If the user says "let's model" / "what's in the backlog?" with nothing new → offer REFINE or CAPTURE-something-new
- If the user says "promote X" / "X is ready" → PROMOTE
- If ambiguous, ask once. Don't guess wrong and then have to undo.

### Identifying which task the user means (REFINE / PROMOTE)

When the user references an existing task, support all of these:

- **Exact id** — `books-007` → that exact task
- **Numeric only** — `007` → find task with that number across all BCs; if multiple BCs have the same number, list them and ask
- **Keyword / fuzzy** — `password` or `reading session` → match substring (case-insensitive) against task `title` and filename across `backlog/` and `todo/` of all BCs
- **No argument** — list all backlog (and todo, for PROMOTE context) tasks grouped by BC and let the user pick

When there are multiple matches, show a compact summary (id, title, status, BC) and ask which one — don't silently pick the first.

## Before acting

Read the current state:
1. `.agenthoff/vision.md` (for context — if missing, offer to run `brainstorm` first)
2. `.agenthoff/context-map.md` (if exists)
3. `.agenthoff/contexts/*/README.md` (to know what BCs exist and their language)
4. `.agenthoff/contexts/*/backlog/*.md` (to understand what's pending)

If no bounded contexts exist yet, and the idea is non-trivial, propose running `brainstorm` first. Small ideas (bug fixes, copy changes) in a greenfield project can get a default `contexts/main/` until real structure emerges.

## CAPTURE flow

1. **Understand the idea.** If the user gave one sentence, ask follow-ups to get: the why, the acceptance criteria, anything that constrains the solution. Don't ask more than 3-4 questions. For tiny things ("change button color"), one question may be enough, or none.

2. **Route to the right bounded context.** Match the idea's language to a BC's ubiquitous language. If it spans multiple BCs, say so and create a task in each (or a parent+child structure — see below). If it doesn't fit any BC and isn't trivial, that's a signal the context map needs revisiting — surface it.

3. **Decide refinement level.**
   - **Under-refined → backlog/**: The idea needs more thought, research, or breaking down before anyone could work on it.
   - **Ready → todo/**: The idea is small, well-understood, or already deeply discussed. A worker could pick it up and execute without ambiguity.

4. **Delegate deep modeling if needed.** For complex ideas (new feature, domain change, architectural impact), spawn the **orchestrator** agent with the idea and current state. It will route to `tactical-modeler`, `strategic-modeler`, `architect`, or `researcher` as appropriate, and come back with a refined task (or task set) plus any ADRs.

5. **Write the task file(s).** See task format below.

## REFINE flow

1. If no specific backlog item was named, list the backlog across all contexts and ask which to refine. Prefer oldest-first or user-priority if flagged.

2. Read the task, its BC's README, and any related tasks (dependencies, siblings).

3. **Interrogate the task.** Questions typically needed:
   - Is the goal still correct?
   - What are the acceptance criteria?
   - What does this depend on? What depends on it?
   - Does this split into smaller tasks?
   - Does this reveal a decision that should become an ADR?

4. **Delegate to the orchestrator** for depth. Give it the task and the BC context. It will route to specialists.

5. **Update the task file** with refined content. If it splits, create child tasks and update `depends_on`. If a decision was made, write an ADR to `.agenthoff/knowledge/decisions/`.

6. **Promote if ready.** If refinement made the task ready, move it to `todo/`.

## PROMOTE flow

1. Find the task (user may name it by id or title, or describe it).

2. Check readiness:
   - Has an acceptance criteria section with at least one concrete criterion
   - Has a clear scope (not "improve the UX")
   - Dependencies are known and either met or tracked

3. If ready, move the file from `backlog/` to `todo/`. Update its frontmatter `status` field.

4. If not ready, tell the user what's missing and offer to enter REFINE mode on this task.

## Task file format

Files live as `contexts/<bc>/<status>/<id>-<slug>.md`. Example: `contexts/auth/backlog/auth-003-password-reset-flow.md`.

```markdown
---
id: auth-003
title: Password reset flow
status: backlog         # backlog | todo | doing | done
type: feature           # feature | bug | refactor | chore | spike | decision
context: auth
created: 2026-04-24
completed:              # set by worker when done
commit:                 # git SHA set by worker when done
depends_on: []          # list of task ids
blocks: []              # populated automatically by worker / refine
tags: []
---

## Why
Why this exists. The user problem or domain pressure behind it.

## What
What the change is, in domain language.

## Acceptance criteria
- [ ] Concrete, testable outcomes.
- [ ] One bullet per criterion.

## Notes
Open questions, links to ADRs, references to research reports,
rough sketches — anything a worker or refiner would want.
```

### ID convention

`<bc-short>-<zero-padded-number>`, e.g., `auth-003`, `billing-017`. Look at existing task files in the BC to determine the next number. Keep IDs stable — never renumber, even after deletions.

## Decisions as tasks

When modeling surfaces a genuine architectural or domain decision that deserves its own treatment (rather than being an implementation detail of a feature), create a task with `type: decision`. Its output when worked is an ADR in `.agenthoff/knowledge/decisions/`, not code. This lets decisions flow through the same backlog discipline as features.

## Delegating to the orchestrator

The `model` skill itself does not do deep modeling — it routes. For anything non-trivial, hand off to the `orchestrator` agent with:
- The idea or task being refined
- The target BC's README (ubiquitous language)
- The vision.md
- The context map
- A clear question: "refine this task" or "decompose this idea into tasks" or "tell me what BCs this touches"

The orchestrator picks specialists. Respect its output and integrate it into the task files.

## Research is fair game mid-model

If the user or the orchestrator hits an "we don't know enough about X" wall, kick off the `research` skill in parallel. Continue modeling what you can while research runs; fold its report into the task's Notes section when ready.

## Protocol logging

After each action — CAPTURE, REFINE, or PROMOTE — prepend an entry to `.agenthoff/knowledge/protocol.md`. If `protocol.md` doesn't exist, create it with:

```markdown
# Protocol

Chronological log of everything that happens in this project.
Newest entries on top.

---
```

Then prepend the appropriate entry right after the `---` on line 4:

```markdown
## YYYY-MM-DD HH:MM -- Model / Captured: <task-id> - [title]

**Type:** Model / Capture
**BC:** <bc-name>
**Filed to:** backlog | todo
**Summary:** [1-2 sentences on what the idea is]

---

## YYYY-MM-DD HH:MM -- Model / Refined: <task-id> - [title]

**Type:** Model / Refine
**BC:** <bc-name>
**Status after:** backlog | todo
**Summary:** [what was clarified, added, or split]
**Split into:** [list of new task ids, if split]
**ADRs written:** [list of ADR ids, if any]

---

## YYYY-MM-DD HH:MM -- Model / Promoted: <task-id> - [title]

**Type:** Model / Promote
**BC:** <bc-name>
**From → To:** backlog → todo

---
```

If the action is non-trivial (multiple tasks created from one capture, refinement that produced ADRs, batch promotion), one entry per "thing the user asked for" is enough — don't prepend five entries for a single conversation turn.

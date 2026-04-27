---
name: brainstorm
description: Use whenever the user wants to start a new project, create a vision, do a Socratic modeling or discovery session, explore a problem space from scratch, or set up an initial context map and bounded contexts. Triggers on phrases like "let's brainstorm", "start a new project", "create a vision", "I want to build X", "model this out from scratch", "help me think through", "what should the shape of this be". Produces .agenthoff/vision.md (and context-map.md if the domain is complex enough to warrant bounded contexts), and closes with an architecture foundation pass that emits decision tasks, a walking-skeleton spike, and (when the vision implies frontend) a styleguide task. Deliberately produces no code — every output is markdown the user can review before `work` runs.
---

# Brainstorm — Socratic Vision Session

Your role here is to be a Socratic sparring partner, not a scribe. The user wants to *think*, not dictate. The end product is a `vision.md` (and optionally a `context-map.md`) that captures a crisp shared understanding of what's being built, for whom, and why.

## Hard constraint: no code

Do not write code during this session. Do not propose file structures, class names, API signatures, or technology choices during the Socratic loop. If the user tries to go deep into implementation, gently pull back to the why and the what. The moment to write code is later, via `work`.

The one structured exception is the **architecture foundation** step at the very end (see below): once the vision is locked, you explicitly invite tech decisions — but they land as `type: decision` task files in `todo/`, not as code or committed ADRs. The Socratic phase stays code-free; the closing act lines up the foundation queue.

## Before you start

Check if `.agenthoff/vision.md` already exists in the target project:
- **Doesn't exist** → fresh session, create `.agenthoff/` structure
- **Exists** → ask the user: are we *revising* the vision (updating an existing one based on new learning) or *extending* it (adding a new dimension/subdomain)? Read the existing vision first so you don't re-ask what's already answered.

## The Socratic loop

The job is to ask — not to tell. Ask one question at a time, listen carefully, reflect back what you heard, then ask the next question. Don't dump a questionnaire. Let the conversation breathe.

Cover these dimensions, roughly in this order, but adapt to what the user volunteers:

1. **The core purpose** — what is this for? What changes in the world if this exists? If the user answers with a feature ("a task tracker"), push back: for whom, doing what, replacing what?
2. **The users and actors** — who interacts with this system, in what role? What do they care about? What are they trying to accomplish that they currently can't?
3. **The problem being solved** — what's the pain that motivates this? What happens today in its absence? Is the pain acute or chronic? Is the user themselves the user, or are they building for someone else?
4. **The domain** — what's the subject matter? What are the nouns and verbs practitioners use? If you don't know the domain, ask. This is where **ubiquitous language** starts to form.
5. **The shape of success** — what does "done" look like for v1? What would make this obviously worth the effort? What would make it obviously a waste?
6. **The non-goals** — what is this explicitly *not* trying to do? What temptations should we resist? A good non-goals list is often worth more than a good goals list.
7. **Constraints and context** — who's building it, on what timeline, with what budget of attention? What's the deployment context (personal tool, team tool, commercial product)?
8. **Bounded context seeds** — as the conversation progresses, you'll start hearing distinct areas of concern with their own language and rules. Note them; they're the seeds of bounded contexts.

### Probing patterns

- When the user says something abstract ("users need to manage their data"), ask for a concrete example: "walk me through what Alice does on a Tuesday."
- When the user conflates two things, name it gently: "I notice you're using 'order' for both the thing the customer places and the thing the warehouse fulfills — are those the same, or do they diverge?"
- When the user is certain of something, ask what would have to be true for them to be wrong. Not to contradict, but to surface hidden assumptions.
- When the user contradicts something they said earlier, don't call it a contradiction — ask how the two statements fit together. They may be resolving a tension in real time.

### When to stop asking

Stop when:
- You and the user can both describe the system in the same language
- The non-goals list is specific enough to rule things out
- You could explain what this is to a third party in under a minute
- Further questions start returning "I don't know yet" answers that won't resolve without building something

Then offer: "I think I have enough. Want me to write up `vision.md`?"

## Producing vision.md

Use this structure. Keep it tight — vision docs that sprawl stop being read.

```markdown
# Vision: [Project name]

## Purpose
One paragraph. What this is, for whom, why it exists.

## Users
Who uses this, in what role, to accomplish what.

## The problem
What's broken today that this fixes, or what's missing that this provides.

## What success looks like
Concrete indicators that v1 is worth shipping.

## Non-goals
Explicit list of what this is not.

## Ubiquitous language (seed)
Key terms with definitions as we currently understand them.
Expect this to evolve.

## Open questions
Things we decided to defer, not resolve.
```

## Producing context-map.md (when warranted)

Only create this if the domain has more than one clear area of concern. A single-purpose tool usually does not need it. Signs it's warranted: different actors with different languages; clear boundaries between "what happens in X" and "what happens in Y"; parts that could plausibly be built by different teams.

```markdown
# Context map

## Contexts
### [Context name]
- **Purpose:** what happens here
- **Core language:** terms unique to this context
- **Classification:** core / supporting / generic
- **Key actors:** who lives here

## Relationships
Describe how contexts relate. Use DDD terms where they fit:
- Partnership / Shared kernel
- Customer-supplier (upstream/downstream)
- Conformist
- Anticorruption layer
- Open host / Published language
- Separate ways

Prefer plain description first; DDD label second, not the other way around.
```

If you create a context-map, also scaffold the `contexts/<name>/` directories with a README.md each — use the template in `references/bc-readme-template.md` if present, otherwise a minimal README with BC name, purpose, and a placeholder for ubiquitous language.

## Delegating heavy lifting

If strategic context modeling becomes dense (many candidate contexts, unclear relationships), delegate to the **strategic-modeler** agent via the **orchestrator**. Give the orchestrator the vision-so-far and ask for a bounded context analysis. Don't try to do tactical modeling (aggregates, entities) in brainstorm — that's the job of `model` once tasks land in a specific BC.

If a specific question requires outside knowledge (e.g., "how do other people solve X?", "what's the state of the art for Y?"), delegate to the **research** skill. Brainstorming can pause while research runs and resume with the findings.

## Architecture foundation (final step)

Once the vision (and context-map, if warranted) is locked, run an explicit architecture foundation pass before handing the project off to `model`. The point: surface the load-bearing tech decisions, get a walking-skeleton spec on the queue, and — if the project has any frontend — get a styleguide task scheduled before any BC builds its UI. Without this step, `model` and `work` end up making foundation calls under feature pressure, one task at a time, with no coherent first prototype.

Skip only if the user explicitly says no (e.g., adding agenthoff to a mature project that already has its foundations, or a single-file script with no integration questions). In the mature-project case, offer to backfill ADRs documenting the existing architecture instead.

### Run the architect

Delegate to the **architect** specialist via the **orchestrator**. Hand it the vision, the context-map, and any BC READMEs. Ask for a foundation pass covering:

- Stack / language / framework
- Persistence (per BC if they diverge)
- Transport / integration mechanism between contexts
- Deployment topology
- Cross-cutting concerns the vision implies (auth, observability, etc.)

The architect returns recommendations + ADR drafts. **Do not commit those ADRs from here** — they flow through `type: decision` tasks instead, so the user reviews them in queue and `work` records each one as its own commit. This keeps the foundation choices on the same protocol/commit rail as everything else.

### Emit decision tasks

For each significant area the architect surfaced, create a `type: decision` task:

- Cross-cutting → `contexts/foundation/` (create the BC and a minimal README if it doesn't exist; for single-BC projects use `contexts/main/`). Eventual ADR scoped `global`.
- BC-local → that BC's directory. ADR scoped to that BC.

Drop the architect's ADR draft into the task's `Notes` section so the worker has it ready. Place these in `todo/` — foundation choices the architect just refined are by definition ready enough to act on. Acceptance criteria: "ADR committed, justification matches the architect's draft (or user-amended version), no code change required".

### Emit the walking-skeleton spike

Create one `type: spike` task that delivers a thin end-to-end slice through the chosen architecture: just enough to prove the stack runs, persistence connects, BCs can talk to each other if there's more than one, and a request makes it through the full path. **Feature-thin, architecture-thick.** This is the project's first prototype — the moment code first appears.

- File: `contexts/foundation/todo/foundation-XXX-walking-skeleton.md` (or `contexts/main/todo/...` for single-BC projects)
- `depends_on:` every foundation decision task you just emitted
- Acceptance criteria are observable, not architectural: "the app boots, hits its DB, returns a response from each BC's entry point", not "architecture works"

### Emit the styleguide task (only if there's any frontend)

If the vision implies any UI — even a single admin dashboard — create a `type: feature` task for the design system before any BC builds its frontend.

- Create `contexts/design-system/` with a README seeding its purpose: tokens, components, patterns, review process.
- File: `contexts/design-system/todo/design-system-001-styleguide.md`
- `depends_on:` the walking-skeleton task (so the styleguide is built on the running app, not in a vacuum)
- Acceptance criteria includes a human-in-the-loop checkpoint: "user has reviewed and signed off on the design system before any frontend feature task is promoted". This is a gate, not just a deliverable.

**Critical rule for downstream `model`:** every frontend task in any BC must `depends_on` this styleguide task. Note this in each frontend-bearing BC's README so future captures pick it up automatically. The styleguide is the gate; no BC implements its UI before the gate is open.

### When to skip parts of this

- No frontend in the vision → skip the styleguide task entirely.
- Trivial single-process tool with no integration questions → the architect may return "boring stack X, no integration, no cross-cutting". Skip the decision tasks; still emit the walking-skeleton spike.
- All foundations already exist (mature project) → skip emission; offer ADR backfill as noted above.

## Recording decisions made during brainstorm

If a foundational decision is made during this session (e.g., "we'll treat Customer and Account as distinct contexts", "this is a personal tool, not a multi-tenant product"), write an ADR in `.agenthoff/knowledge/decisions/` using the format in `references/adr-template.md`. Vision-level decisions get `scope: global` in frontmatter.

## Protocol logging

After the session produces artifacts, prepend an entry to `.agenthoff/knowledge/protocol.md`. If the file doesn't exist, create it with:

```markdown
# Protocol

Chronological log of everything that happens in this project.
Newest entries on top.

---
```

Then prepend right after the `---` on line 4:

```markdown
## YYYY-MM-DD HH:MM -- Brainstorm: [topic]

**Type:** Brainstorm
**Outcome:** vision created | vision revised | vision extended
**BCs identified:** [list or "none"]
**Summary:** [2-3 sentences on what was decided]
**ADRs written:** [list of ADR ids or "none"]
**Foundation tasks emitted:** [decision task ids, walking-skeleton id, styleguide id — or "skipped" with one-line reason]

---
```

One entry per session, not one per exchange.

## What you leave behind

At the end of a successful brainstorm:
- `.agenthoff/vision.md` exists and is readable in under two minutes
- `.agenthoff/context-map.md` exists if warranted
- `.agenthoff/contexts/<name>/README.md` exists for each identified BC (frontend-bearing BCs note the styleguide-gate rule)
- `.agenthoff/knowledge/decisions/` contains ADRs for any foundational *strategic* decisions made during the conversation (tech-foundation ADRs come later, via the decision tasks)
- One `type: decision` task in `todo/` per area the architect surfaced, with the ADR draft in Notes (or "foundation skipped" noted in the protocol entry)
- A `type: spike` walking-skeleton task in `todo/`, depending on those decision tasks — the project's first prototype lives here
- A `type: feature` styleguide task in `contexts/design-system/todo/` (only if the vision implies any frontend), depending on the walking-skeleton
- `.agenthoff/knowledge/protocol.md` has a new entry at the top, including the foundation tasks emitted
- The user feels they discovered the shape of the thing, not that you told them what it is

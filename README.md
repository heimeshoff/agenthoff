# agenthoff

A DDD-flavored agentic harness for Claude Code. Installed as a plugin once, used across projects. It turns a raw idea into a vision, a vision into a modeled backlog of bounded contexts, and a backlog into parallel, dependency-aware execution — with ADRs, a protocol log, and per-BC READMEs falling out naturally.

## Install

From inside Claude Code, in the project where you want the plugin:

```
/plugin marketplace add <path-to-this-repo>
/plugin install agenthoff@agenthoff
```

`<path-to-this-repo>` is the absolute path to a local clone (e.g. `C:/src/heimeshoff/tooling/agenthoff`) or a `git` URL. The first command registers this repo as a marketplace; the second installs the plugin from it. Restart Claude Code afterward so hooks and skills are picked up.

### Updates

#### Releasing a change (maintainer side)

When you change anything that consumer projects should pick up — a skill, an agent, a hook, a slash command — bump the `version` field in `.claude-plugin/plugin.json` and commit. Updates are only detected when the version *changes*: that field is the authority. Use semver: bump the patch for fixes, the minor for new behavior, the major for breaking changes to skill contracts or hook shapes.

If you'd rather not bump by hand, omit the `version` field entirely and Claude Code falls back to the git commit SHA — every commit then counts as a new version. The trade-off is that consumers see noise from every internal commit, not just intentional releases.

After committing (and pushing, if the marketplace points at a `git` URL rather than a local path), consumers can pull the change with the steps below.

#### Pulling a change (consumer side)

Local/third-party marketplaces have auto-update **disabled** by default. To enable it, run `/plugin`, go to the **Marketplaces** tab, select `agenthoff`, and choose "Enable auto-update". Claude Code will then refresh on startup and prompt you to run `/reload-plugins` when there's a new version.

To update manually:

```
/plugin marketplace update agenthoff
/plugin update agenthoff@agenthoff
/reload-plugins
```

The first command refreshes the marketplace's view of the source repo, the second pulls the new plugin version into your project, and the third reloads skills/hooks so the change is live in the current session.

## The four skills

Skills auto-trigger from natural-language phrases — no slash commands to memorize. The orchestrator agent routes work to specialists (strategic-modeler, tactical-modeler, architect, researcher, worker).

| Skill | Triggered by | Produces |
|---|---|---|
| **brainstorm** | "let's brainstorm", "start a new project", "create a vision", "model this from scratch" | `.agenthoff/vision.md` (+ `context-map.md` when warranted). Closes with an architecture foundation pass that emits `type: decision` tasks, a walking-skeleton spike, and (when frontend exists) a styleguide task. No code yet — those land in `todo/` for `work` to execute. |
| **model** | "I have an idea", "capture this", "refine the auth backlog", "promote X to todo", "there's a bug" | Task markdown files in `contexts/<bc>/backlog\|todo/` with status, dependencies, acceptance criteria. |
| **work** | "start working", "execute the todo", "let's go", "pick up where you left off" | Code, commits, ADRs. Parallel workers respect the dependency DAG. |
| **research** | "research X", "state of the art for", "compare options for" | A markdown report in `.agenthoff/knowledge/research/`. Cited by tasks and ADRs. |

## The workflow

```
brainstorm  →  vision.md, context-map.md, foundation queue (decision tasks + walking-skeleton spike + styleguide task)
    ↓
model       →  backlog/ (fuzzy) → refined → todo/ (ready)
    ↓
work        →  doing/ → done/, commits, ADRs, updated BC READMEs  (first prototype = walking-skeleton spike)
    ↑
research    ←  (called from any of the above when external knowledge is needed)
```

- **brainstorm** is Socratic and deliberately produces no code. The output is shared understanding plus a foundation queue (decision tasks, walking-skeleton spike, styleguide task) so `work`'s first prototype runs on real architecture, and frontend BCs build against a reviewed design system.
- **model** has three actions: CAPTURE (new ideas), REFINE (deepen a backlog item), PROMOTE (backlog → todo). It routes through the orchestrator to the right specialist.
- **brainstorm** and **model** both support six switchable conversational modes — **Interrogator** (default, naive/critical questions), **Suggestor** (smart proposals), **Challenger** (adversarial pushback), **Storyteller** (concrete scenarios), **Facilitator** (scribe stance, humans drive), **Synthesizer** (reflects tensions). Switch mid-session ("be the storyteller", "facilitator mode"). Designed for workshop and group-modeling settings. See `references/modes.md`.
- **work** is a loop, not a one-shot. It resumes interrupted sessions, builds the dependency DAG, dispatches up to 3 parallel workers, and picks up tasks promoted mid-run.
- **research** is called explicitly by you or implicitly when another skill hits an "I don't know enough" wall.

## Architecture foundation and the first prototype

The Socratic brainstorm phase deliberately stays code-free *and* tech-choice-free — but ending there would leave foundation calls (stack, persistence, transport, deployment topology, cross-cutting concerns) to be made later, one at a time, under feature pressure. So `brainstorm` ends with a structured **architecture foundation** step that lines those decisions up explicitly, while the room is still calm.

The closing step:

1. **Calls the `architect` specialist** via the orchestrator with the vision and context map. The architect proposes options + trade-offs + ADR drafts across stack, persistence, integration, deployment, and obvious cross-cutting concerns.
2. **Emits one `type: decision` task per area** (in `contexts/foundation/todo/` for cross-cutting, or the relevant BC for BC-local choices). The architect's ADR draft lives in the task's `Notes` — the user reviews it in queue, and `work` commits each ADR as its own commit. Foundation choices ride the same protocol/commit rail as features.
3. **Emits a `type: spike` walking-skeleton task** that depends on every foundation decision. Feature-thin, architecture-thick: the stack runs, persistence connects, BCs talk to each other if there's more than one, a request makes it through end-to-end. This is the project's **first prototype** — the moment code first appears in the repo.
4. **If the vision implies any frontend, emits a `design-system-001-styleguide` task** in `contexts/design-system/todo/`, depending on the walking skeleton. Acceptance includes a human-in-the-loop sign-off.

The closing step is skippable when it doesn't fit: mature project being adopted (offer ADR backfill of existing architecture instead), single-file script with no integration questions, no frontend (skip just the styleguide).

### Styleguide gate for frontend work

Once the styleguide task exists, **every frontend task in any BC must `depends_on` the styleguide**. `model` enforces this on capture: if you try to capture frontend work in a project that has no styleguide task yet, it stops and asks you to either run `brainstorm`'s foundation step or capture a styleguide task explicitly first. The styleguide is reviewed with you before any BC implements its UI — that prevents per-BC drift in the design language.

## Project state layout

All state for a project lives in `.agenthoff/` inside that project — never in the plugin dir:

```
.agenthoff/
├── vision.md
├── context-map.md                      # only for multi-BC domains
├── contexts/
│   └── <bounded-context>/
│       ├── README.md                   # ubiquitous language, aggregates, events
│       ├── backlog/                    # captured, not yet refined
│       ├── todo/                       # ready to work
│       ├── doing/                      # in flight (claimed by a worker)
│       └── done/                       # completed, linked to commit SHA
└── knowledge/
    ├── protocol.md                     # chronological diary, newest on top
    ├── adrs/                           # architectural decision records
    └── research/                       # research reports
```

Tasks are plain markdown with frontmatter (`id`, `status`, `depends_on`, `type`). One task = one commit, made by the work skill after the worker reports `SUCCESS`. Workers return a strict `RESULT/TASK_ID/SUMMARY/FILES_CHANGED/...` format to keep the orchestrator context lean across long batches.

Scaffolding is English; your own domain language can be in any language.

## Sound notifications

The plugin plays a short sound when Claude finishes a task (`Stop` hook) or is waiting for your input (`Notification` hook) — distinct sounds for each, using built-in Windows `SystemSounds`.

Toggle with the slash command:

```
/sound          # show current state
/sound on       # enable
/sound off      # mute
```

State sentinel lives at `~/.agenthoff/sound-disabled` (present = muted, absent = on; default on). Windows-only for now (PowerShell + `System.Media.SystemSounds`).

To use custom sound files, replace the two `SystemSounds.*` lines in `scripts/play-sound.ps1` with `(New-Object System.Media.SoundPlayer '<path>').PlaySync()`.

## Layout of this repo

```
.claude-plugin/plugin.json    # plugin manifest
agents/                       # orchestrator + specialists
skills/                       # brainstorm, model, research, work
hooks/hooks.json              # Stop + Notification sound hooks
scripts/play-sound.ps1        # sound player (reads toggle sentinel)
commands/sound.md             # /sound slash command
evals/                        # benchmarks against other harnesses
references/                   # design notes and source material
```

## Status

Iteration 1 validated (2026-04-24). Benchmarked at 100% vs. 54.8% on the reference suite. Load-bearing disciplines — no-code brainstorm, strict worker return format, orchestrator never writing code, protocol log on every action — are intentional and should not be regressed.

## License

See `LICENSE`.

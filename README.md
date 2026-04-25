# agenthoff

A DDD-flavored agentic harness for Claude Code. Installed as a plugin once, used across projects. It turns a raw idea into a vision, a vision into a modeled backlog of bounded contexts, and a backlog into parallel, dependency-aware execution — with ADRs, a protocol log, and per-BC READMEs falling out naturally.

## Install

From inside Claude Code, in the project where you want the plugin:

```
/plugin marketplace add <path-to-this-repo>
/plugin install agenthoff@agenthoff
```

`<path-to-this-repo>` is the absolute path to a local clone (e.g. `C:/src/heimeshoff/tooling/agenthoff`) or a `git` URL. The first command registers this repo as a marketplace; the second installs the plugin from it. Restart Claude Code afterward so hooks and skills are picked up.

To update later: `/plugin marketplace update agenthoff` then `/plugin update agenthoff@agenthoff`.

## The four skills

Skills auto-trigger from natural-language phrases — no slash commands to memorize. The orchestrator agent routes work to specialists (strategic-modeler, tactical-modeler, architect, researcher, worker).

| Skill | Triggered by | Produces |
|---|---|---|
| **brainstorm** | "let's brainstorm", "start a new project", "create a vision", "model this from scratch" | `.agenthoff/vision.md` (+ `context-map.md` when the domain warrants bounded contexts). No code. |
| **model** | "I have an idea", "capture this", "refine the auth backlog", "promote X to todo", "there's a bug" | Task markdown files in `contexts/<bc>/backlog\|todo/` with status, dependencies, acceptance criteria. |
| **work** | "start working", "execute the todo", "let's go", "pick up where you left off" | Code, commits, ADRs. Parallel workers respect the dependency DAG. |
| **research** | "research X", "state of the art for", "compare options for" | A markdown report in `.agenthoff/knowledge/research/`. Cited by tasks and ADRs. |

## The workflow

```
brainstorm  →  vision.md, context-map.md
    ↓
model       →  backlog/ (fuzzy) → refined → todo/ (ready)
    ↓
work        →  doing/ → done/, commits, ADRs, updated BC READMEs
    ↑
research    ←  (called from any of the above when external knowledge is needed)
```

- **brainstorm** is Socratic and deliberately produces no code. The output is shared understanding.
- **model** has three modes: CAPTURE (new ideas), REFINE (deepen a backlog item), PROMOTE (backlog → todo). It routes through the orchestrator to the right specialist.
- **work** is a loop, not a one-shot. It resumes interrupted sessions, builds the dependency DAG, dispatches up to 3 parallel workers, and picks up tasks promoted mid-run.
- **research** is called explicitly by you or implicitly when another skill hits an "I don't know enough" wall.

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

# Bounded context README template

Every `.agenthoff/contexts/<bc-name>/README.md` uses this shape. It's the home of the BC's ubiquitous language and the first thing any specialist or worker reads before touching the BC.

```markdown
# [Context name]

## Purpose
One or two sentences. What happens inside this context that does not happen elsewhere.

## Classification
core | supporting | generic

Brief note on why. If the classification changes, update this and write an ADR.

## Actors
Who interacts with this context and in what role.

## Ubiquitous language
Terms and their definitions, in the language the domain uses.
Keep this in sync with how tasks, code, and ADRs inside this BC talk.

- **Term A** — definition
- **Term B** — definition, and how it differs from a similar term elsewhere

## Aggregates
Named aggregates with their invariants in one line each.
Detailed aggregate design lives in tactical modeling / tasks / code, not here.

- **Aggregate X** — protects invariant Y

## Key events
Domain events that leave this context. Past-tense, domain-language.

## Key commands
Intents that enter this context.

## Relationships with other contexts
Brief note per relationship. Defer the full map to context-map.md.

- **Upstream of:** context A via event Z
- **Conformist to:** external system B

## Open questions
Things the team hasn't decided yet about this context.
```

## Writing guidance

- **Ubiquitous language is the core value of this document.** If you cut anything, don't cut that.
- **Don't duplicate the context map.** The relationships section should be one-liners pointing back to the map.
- **Don't put implementation details here.** File structure, library choices, database schema — those live in code and ADRs, not in the BC README.
- **Revisit it when the BC changes.** Out-of-date ubiquitous language is worse than none.

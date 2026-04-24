---
name: research
description: Use whenever the user or another skill needs external information gathered from the web — state of the art on a topic, comparison of approaches, documentation for a library, domain knowledge from outside the codebase. Triggers on phrases like "research X", "find out about", "what's the state of the art for", "look up how others do", "compare options for", "gather info on", and also triggers internally when brainstorm or model hits an "I don't know enough" wall. Produces a research report in .agenthoff/knowledge/research/ that can be referenced from tasks, ADRs, and modeling sessions.
---

# Research — Web Investigation with Written Output

The `research` skill is how external knowledge enters the workflow. It runs WebFetch and WebSearch, synthesizes the findings, and produces a markdown report that other skills can cite.

## Scope

Research is about understanding, not decision-making. Produce a report; do not produce an ADR. Decisions come later — in `model` or `work` — and they cite research reports.

## Inputs

Accept one of:
- A concrete question ("how do people implement optimistic locking in event-sourced systems?")
- A topic area ("rate limiting strategies")
- A library/product name ("Temporal.io — what does it do and who uses it?")

If the request is vague ("research auth"), narrow it once with the user before running.

## Running

Delegate to the `researcher` agent. The researcher will:
1. Start with WebSearch for a breadth pass
2. Follow up with WebFetch on the most promising 3–7 sources
3. If multiple independent angles exist, run them in parallel (multiple WebSearch/WebFetch tool calls in the same message)
4. Cross-check claims across sources — single-source claims get flagged as such
5. Write the report

## Report format

Files land at `.agenthoff/knowledge/research/<slug>-<date>.md`:

```markdown
---
topic: [one-line topic]
date: 2026-04-24
requested_by: [brainstorm | model | work | user]
related_tasks: []
---

# Research: [Topic]

## Question
What we wanted to know, in one or two sentences.

## Summary
3–6 bullet answers. Lead with what's decision-relevant, not with what's novel.

## Findings
Subsections as needed. Each claim cites its source(s). Disagreements
between sources are named, not hidden.

## Sources
Numbered list with URL, title, and one-line relevance note per source.

## Open questions
Things we wanted to answer and couldn't, or that would need primary research.
```

## Linking back

When a research report influences a task or decision:
- The task's Notes section gets a link to the report
- The ADR (if one results) gets the report in its references
- The report's frontmatter `related_tasks` gets updated

This bidirectional linking is how knowledge stays findable.

## Protocol logging

After writing the report, prepend an entry to `.agenthoff/knowledge/protocol.md` (creating the file with its header if missing — see brainstorm/model/work skills for the header template):

```markdown
## YYYY-MM-DD HH:MM -- Research: [topic]

**Type:** Research
**Requested by:** brainstorm | model | work | user
**Report:** knowledge/research/<slug>-<date>.md
**Summary:** [2-3 bullet findings]

---
```

## Parallelism

Research is naturally parallelizable. If the user asks for research on multiple distinct topics, spawn multiple researcher agents rather than serializing. Each writes its own report.

## What NOT to do

- Do not fetch URLs the user did not authorize and that you don't have independent reason to trust
- Do not paraphrase without source attribution — readers need to trace claims
- Do not write advocacy — the report should leave the decision to the reader
- Do not let research scope-creep into a dissertation. Stop when the question is answered to decision-adequate depth.

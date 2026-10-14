---
title: decision template
type: template
status: approved
owner: team
task: none
updated: 2026-10-14
source: none
related:
  - ../00-index.md
---

Blank template for decision notes. Copy it, never edit it.

```yaml
---
title: short kebab-case topic
type: decision
status: draft
owner: name
task: Txx or none
updated: YYYY-MM-DD
source: file path plus line, or commit hash
related:
  - ../00-index.md
---
```

One-line summary of the decision.

## Decision

What was decided, in one or two sentences.

## Context

Why the decision was needed.

## Values changed

| File | Key | Old | New |
|------|-----|-----|-----|
| path | key | old | new |

## Approved by

Name and date. Locked values need team sign-off per AGENTS.md.

## Design doc lines to update

File and line for each canonical doc line that must change. Do not edit those docs from here.

## Status

draft, approved, or done.

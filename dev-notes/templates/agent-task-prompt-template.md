---
title: agent task prompt template
type: template
status: approved
owner: team
task: none
updated: 2026-10-14
source: none
related:
  - ../00-index.md
---

Blank template for step-gated agent prompts. Copy it, never edit it.

```yaml
---
title: YYYY-MM-DD topic
type: prompt
status: draft
owner: name
task: Txx or none
updated: YYYY-MM-DD
source: none
related:
  - ../00-index.md
---
```

One-line summary of the requested work.

## Read first

List the exact files and line ranges, for example `src/ReplicatedStorage/Config.lua` and `.gemini/TASK.md`.

## Rules

- Small reviewed steps with approval stops.
- Docs and notes only, or code under `src/`, per the task.
- Never touch locked values without sign-off.
- Plain sentences, no em dashes.

## Steps

Each step ends with a stop for approval.

- Step 1: inspect and plan, no writes. Stop.
- Step 2: implement. Stop.
- Step 3: verify and report. Stop.

## Report format

Tree of changed files, test results, open questions, and the AI_LOG.md row text.

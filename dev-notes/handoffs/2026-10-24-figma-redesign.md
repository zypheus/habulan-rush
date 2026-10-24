---
title: Figma UI redesign handoff
type: handoff
status: awaiting-owner-review
owner: project-owner
task: figma-ui-redesign
updated: 2026-10-24
source: 2026-10-24 owner-approved Habulan Rush Figma redesign proposal
related:
  - ../current-task.md
  - ../../AI_LOG.md
---

# Figma UI redesign handoff

## File and final references

- [Roblox UI Figma file](https://www.figma.com/design/Z1d6qBBLV8al8sqmRrGv6C/Roblox-Ui) contains Foundations, Screens, and Journey and Handoff pages. The local design system uses `Config.UI.Theme` colors, Oswald headings, Montserrat body previews, color and metric variables, text styles, and editable panel, button, timer, standing, notice, mode-card, and control-prompt components.
- The Screens page contains desktop and landscape-phone loading, lobby, party, queue, profile, help, settings, mode vote, Classic Kalsada map vote, Bato Bato pick, countdown, and all three mode HUD flows.
- [Final HUD reference](https://www.figma.com/design/Z1d6qBBLV8al8sqmRrGv6C/Roblox-Ui?node-id=15-20) is the implementation reference for live metrics and controls. It shows Panyo hold time and automatic pickup and holding, Classic Taya time, and Hunt capture counts with private target cards. Landscape-phone standings show the top three plus an expanded eight-player state.
- [Final results reference](https://www.figma.com/design/Z1d6qBBLV8al8sqmRrGv6C/Roblox-Ui?node-id=16-20) is the implementation reference for Classic, Panyo, and Hunt round and match results, practice, tie, no-MVP, and expanded phone standings. Transitions are server timed. Earlier result and HUD frames are exploratory drafts and are superseded by these two final references.
- [Journey and device handoff](https://www.figma.com/design/Z1d6qBBLV8al8sqmRrGv6C/Roblox-Ui?node-id=14-2) includes the annotated journey, screen inventory, tablet and small-phone checks, gamepad focus, high-contrast state, Hunt privacy comparison, implementation order, and owner review checklist. The [final-reference note](https://www.figma.com/design/Z1d6qBBLV8al8sqmRrGv6C/Roblox-Ui?node-id=17-2) identifies the authoritative screen groups.

## Design decisions

- Filipino street arcade styling uses the existing navy, cream, gold, teal, Runner blue, and Taya red palette. Facades, courts, tactile lips, and restrained stud details are original vector shapes. No bundled third-party art or unverified competition asset was used.
- The live first-person view keeps the center open. One timer, an immediate role or objective cue, contextual mode state, and readable standings occupy the edges. Earned sprint is automatic after valid actions; no stamina or manual sprint control is depicted.
- Classic shows cumulative Taya time. Panyo shows hold time, points, and steals and uses server-observed ring pickup. Hunt shows public capture counts while target identity and hints stay local. Phone views reserve 44 px at the sides and use at least 64 px controls in the final HUD reference.
- The final result flow shows a timed return or next-round countdown. It does not imply a new manual continue action. Settings span two landscape-phone views to retain readable controls.

## Implementation order

1. Translate Foundations tokens and reusable primitives into the existing client UI layer.
2. Implement loading and the lobby family, then settings, help, profile, party, and queue.
3. Implement mode vote, the current one-map Classic ballot, Bato Bato pick, and countdown.
4. Implement the shared timer, objective, standings, control prompts, and focus states.
5. Implement Classic, Panyo, and Hunt overlays, feedback, recaps, and final results using the final references above.
6. Have the project owner validate Studio, desktop, landscape phone, tablet, small phone, gamepad, eight-player density, and two-client Hunt privacy.

## Validation and gaps

- Figma accepted the editable design layers, local variables, styles, and components. Representative Foundations and lobby frames were inspected from Figma screenshots. Final Panyo phone HUD and result source renders were inspected at 844 x 390. The Figma Starter MCP read limit stopped an in-file screenshot pass over every final frame; those frames still need owner visual review in Figma.
- Owner Studio screenshots are not yet available. Device safe areas, focus traversal, text scale, crowded names, touch reach, and actual two-client private Hunt behavior remain unverified in Roblox Studio. No agent Studio test or gameplay execution was run.
- No Luau, gameplay value, map, or asset changed in this design task. No ASSET_LOG entry is needed because the design uses original Figma shapes only.

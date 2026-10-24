---
title: Floating feedback handoff
type: playtest
status: awaiting-owner-test
owner: project-owner
task: floating-action-notifications
updated: 2026-10-24
source: 2026-10-24 owner-approved floating action notifications plan
related:
  - ../current-task.md
  - ../../studio-feedback.project.json
---

# Floating action notifications

- Shared MatchFeedback draws original shape icons and card entrance, upward drift and fade. Match results stay above the reticle; movement cards sit above the momentum meter. Small screens show the latest movement card, desktop shows up to two, to keep the reticle clear. A newer action can replace an older card; otherwise existing lifetimes remain, including three-second roll cards and merged roll chains.
- Slide and roll numeric gains still come from confirmed MomentumUpdate messages. Vault labels appear only from completed local movement, carry no reward and do not imply server-awarded momentum. Interrupted vaults get no card. The momentum bar, sprint chain, audio and participant haptics retain their existing owners.
- Reduced motion or VFX zero gives a static readable card. The existing popup setting hides movement cards while important match notices remain available. Match priority and private Hunt follow-ups remain in place.
- The existing HabulanRushFeedbackSync overlay now includes MomentumHUD, for seven scripts total, restricted to place 127422539599317. No Workspace objects are mapped. Source checks and both builds passed. Reconnecting added the newly mapped MomentumHUD beside the old unmanaged copy. The owner was asked to delete only the old copy containing popupPosition; six other mapped scripts match source exactly.
- No Studio gameplay test, Luau execution, Figma edit or publish was performed. Owner save and gameplay acceptance are pending. Icons are recorded in ASSET_LOG; no asset ID was added.

## Owner checklist

1. Save the same open Edit place after the agent confirms sync. Test with two and eight players in Classic, Panyo and Hunt.
2. Slide, roll and perfect-roll; verify icons, gain amounts, rapid merges, existing sounds and three-second roll duration when not replaced by a later action. Confirm movement cards and match notices can appear independently.
3. Complete normal, speed and airborne vaults. Confirm the correct label without a gain amount. Interrupt a vault against an obstruction, stun or round transition and confirm no completed-vault card.
4. Tag, take or lose Panyo, capture and get caught in Hunt. Check involved-player copy, quiet bystanders, existing slap/haptics and capture/caught before BAGONG TARGET. Misses must not show success.
5. Check death, respawn, round and mode exit for stale cards. Check phone, tablet and desktop safe areas, gamepad, large text and high contrast. The reticle, danger display, controls and sprint chain must remain usable.
6. Set VFX to zero and enable reduced motion: cards should remain readable and static. Disable movement popups: movement cards disappear while match notices remain. Mute SFX and check no new sound bypasses the setting.

## Validation

- Luau syntax, notes, diff whitespace, full and targeted Rojo builds: passed. Final MomentumHUD verification awaits owner duplicate cleanup.
- Follow-up: the owner approved removing the obsolete duplicate. Read-only inspection still finds two enabled MomentumHUD LocalScripts in the same Edit place. Available Studio tools have no dedicated deletion operation; deletion through Luau remains prohibited by AGENTS.md. No deletion was performed. The owner must delete the copy containing `local function popupPosition()` and keep the copy containing `MatchFeedback.showMovement` before final verification.
- Owner save, gameplay and device acceptance: pending.
- Deletion follow-up: the owner reported deleting the old copy. Studio was already in Play mode during the follow-up inspection. The updated MomentumHUD full source matches the UTF-8 repository source, but running-session searches still find the old popupPosition code and duplicate paths. Final Edit-session cleanup verification remains pending until the owner stops their session. The agent did not start or stop play.
- Final Edit follow-up: Studio is confirmed stopped in Edit mode. The explicit Edit-tree search still finds two MomentumHUD LocalScripts, and script search still finds `local function popupPosition()` at line 170. The deletion has not persisted in the Edit place. Owner cleanup in Edit mode remains required.

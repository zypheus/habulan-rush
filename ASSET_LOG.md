# Asset Log — Habulan Rush
_Rule B.6 Compliance: Required by Level Up 3.0 Competition Rules_
_All models, textures, audio, and assets used in the game must be logged here._

**Rule: Only 100% original assets or assets with explicit license for use in a competition submission are allowed. No unauthorized Toolbox models or audio.**

---

## Schema

| Date Added | Asset Name | Type | Source | License | Area Used | Status | Notes |
|------------|-----------|------|--------|---------|-----------|--------|-------|
| Date | Name | Model / Texture / Audio / Script / Font | Creator/Origin | License (e.g. Original, CC0, Roblox TOS) | Which part of the game | Approved / Pending Review | Any notes |

---

## Asset Entries

### Match opening, 2026-10-25

| Date Added | Asset Name | Type | Source | License | Area Used | Status | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-25 | Match opening lineup and title | Runtime Model / Procedural UI | Local copies of current participant characters, existing Kalsada scenery, original Frames and text in MatchShowcase | Existing player avatar and map assets retain their original rights status; original project UI | Six-second first-round opening in all match modes | Pending Review | No external model, animation, image or audio ID introduced. Copies are anchored, noncolliding, nonqueryable, stripped of scripts, tags, attributes and effects, and destroyed at the camera handoff. Existing music and countdown sounds retain their recorded review status. Owner visual acceptance pending. |

### Classic Tag tutorial, 2026-10-25

| Date Added | Asset Name | Type | Source | License | Area Used | Status | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-25 | Tutorial training zone (`assets/TutorialTrainingZone.rbxmx`) | Model | Original Part geometry deterministically emitted by `scripts/build-tutorial-zone.ps1` | Original project geometry | Main place training strip far from Kalsada plus the tutorial subplace; mapped in both projects | Pending Review | Static anchored strip with numbered sign boards, Move, Dash, Sprint, and Tag court discs matched to Config radii, slide rails, a roll platform above the 12-stud hard-landing threshold, a vault crate runway, lampposts, trees, tire stacks, and `SwingBar` and `Zipline` tagged prop models for the MOVEMENT_AUDIT Batch F spec. No external asset ID, texture, audio, Toolbox import, or third-party font (Roblox built-in GothamBold family only). On 2026-10-25 the strip moved into the main place at the owner's single-place direction. |
| 2026-10-25 | TutorialScene waypoints (`assets/TutorialScene.rbxmx`) | Model | Original invisible marker Parts authored in repository | Original project geometry | Main place training strip and tutorial subplace | Pending Review | Seven named markers are separate from the Kalsada map, so a future map can replace them. No external asset ID. On 2026-10-25 the markers moved onto the generated training strip; names, classes, and sizes are unchanged. |
| 2026-10-25 | Anchored tutorial Kalsada (`assets/TutorialMap.rbxmx`) | Model | Derived from the project-owner supplied `assets/Map.rbxmx` | Same pending mesh and texture rights review as the source map | Tutorial subplace only | Pending Review | Set Anchored true on 280 previously unanchored BaseParts so scenery stays in place. Geometry, texture references, and waypoint asset are unchanged. The main-place map keeps its original source asset. |
| 2026-10-25 | Practice Runner, dash gate, and beacon | Model / Script | Original runtime Parts and labels authored in TutorialService | Original project geometry | Tutorial lesson tag step in the main place and the tutorial subplace | Pending Review | Noncolliding gate at DashGoal. No Humanoid, competitive bot, uploaded texture, or external asset ID. The reused Kalsada map retains its existing rights-review status. |

### Floating action icons, 2026-10-24

| Date Added | Asset Name | Type | Source | License | Area Used | Status | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-24 | Slide, roll, vault, tag, cloth, target, clock and loss icons | Procedural UI / Script | Original Frames, corners and strokes authored in MatchFeedback by Codex | Original project UI | Floating action cards | Pending Review | No uploaded or external asset ID. Owner visual acceptance pending. |

### Open authored map import, 2026-10-24

| Date Added | Asset Name | Type | Source | License | Area Used | Status | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-24 | Authored Habulan Rush map and terrain (`assets/Map.rbxmx`, `assets/Terrain.rbxmx`) | Model / terrain | Project-owner supplied open-place export `C:\Users\Acer\Downloads\Hrush.rbxl` | Individual mesh and texture rights unconfirmed | Kalsada full map and continuous round spawns | Pending Review | Imported 475 Workspace-root objects and the existing Map model; preserved layout, added 150 walkable ground tags, 12 invisible spawn regions, and one Panyo marker. SHA-256 and all 58 referenced Roblox IDs are recorded individually in [open map asset inventory](docs/OPEN_MAP_ASSET_INVENTORY.md). Owner must confirm competition-safe rights before release. |
| 2026-10-24 | SpawnRegions and PanyoSpawn (`assets/SpawnRegions.rbxmx`, `assets/PanyoSpawn.rbxmx`) | Model | Derived from the owner-provided map geometry by Codex | Original project geometry | Targeted overlay in the currently open Studio place | Pending Review | Invisible noncolliding sampling volumes and one marker; no new external asset ID. |

### Agawan ng Panyo, 2026-10-23

| Date Added | Asset Name | Type | Source | License | Area Used | Status | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-23 | `HRUSH_Panyo` and pickup ring | Model | Original Roblox primitives and text created in `PanyoMode.lua` | Original | Neutral panyo and Carrier attachment | Pending Review | No Toolbox model or external texture. Runtime visual awaits owner Studio review. |
| 2026-10-23 | `assets/sfx/panyo/pickup.wav` | Audio | Original synthesized cue in `scripts/generate-panyo-sfx.py` | Original | Panyo collection | Pending Upload | Enter approved Roblox ID in `Config.Panyo.Sounds.pickup` after owner upload. |
| 2026-10-23 | `assets/sfx/panyo/steal.wav` | Audio | Original synthesized cue in `scripts/generate-panyo-sfx.py` | Original | Successful steal | Pending Upload | Enter approved Roblox ID in `Config.Panyo.Sounds.steal` after owner upload. |
| 2026-10-23 | `assets/sfx/panyo/drop.wav` | Audio | Original synthesized cue in `scripts/generate-panyo-sfx.py` | Original | Panyo recovery | Pending Upload | Enter approved Roblox ID in `Config.Panyo.Sounds.drop` after owner upload. |
| 2026-10-23 | `assets/sfx/panyo/reveal.wav` | Audio | Original synthesized cue in `scripts/generate-panyo-sfx.py` | Original | Periodic Carrier reveal | Pending Upload | Enter approved Roblox ID in `Config.Panyo.Sounds.reveal` after owner upload. |
| 2026-10-23 | `assets/sfx/panyo/final.wav` | Audio | Original synthesized cue in `scripts/generate-panyo-sfx.py` | Original | Final seconds | Pending Upload | Enter approved Roblox ID in `Config.Panyo.Sounds.final` after owner upload. |

### Wind dash VFX textures, 2026-10-22

| Date Added | Asset Name | Type | Source | License | Area Used | Status | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-22 | Wind streak `rbxassetid://12402893521` (`65`) | Texture | VFX Studio import; Studio reports creator Ekzotericheskiy | Competition-safe rights confirmed by project owner | Runtime `WindDash` burst, Beam, ribbon, and flecks; Studio preview | Approved | Existing imported texture reused; no upload. |
| 2026-10-22 | `HIT EFFECTS 2` `rbxassetid://10198439352` | Texture | VFX Studio import; Studio reports creator ReiAkaris | Competition-safe rights confirmed by project owner | Original Studio `FOOT PULSE` comparison asset | Approved | Preserved in Studio; not referenced by runtime source. |
| 2026-10-22 | `Images/CrystalDebris` `rbxassetid://18453368738` | Texture | VFX Studio import; Studio reports creator Zynclys | Competition-safe rights confirmed by project owner | Original Studio `FOOT PULSE` comparison asset | Approved | Preserved in Studio; not referenced by runtime source. |

### Momentum cues, 2026-10-19

| Date Added | Asset Name | Type | Source | License | Area Used | Status | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-19 | Sfx_GainTick (`rbxassetid://114295533790228`) | Audio | Exact ID supplied by project owner | Provenance confirmation pending | Local momentum gain tick | Pending Review | Played through the existing SFX group; verify competition-safe rights before release. |
| 2026-10-19 | Sfx_TierUp (`rbxassetid://112103056657102`) | Audio | Exact ID supplied by project owner | Provenance confirmation pending | Local momentum tier-up chime | Pending Review | Played through the existing SFX group; verify competition-safe rights before release. |
| 2026-10-19 | Sfx_PerfectRoll (`rbxassetid://125907380174659`) | Audio | Exact ID supplied by project owner | Provenance confirmation pending | Local perfect-roll layer | Pending Review | Played through the existing SFX group; verify competition-safe rights before release. |

### Simple tag animations, 2026-10-18

| Date Added | Asset Name | Type | Source | License | Area Used | Status | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-18 | HRush_TagFirstPerson (`rbxassetid://105436702082738`) | Animation | Exact published ID supplied by project owner | Owner provenance confirmation pending | Local first-person tag action (`Config.Tag.FirstPersonAnimationId`) | Pending Review | Loaded on an isolated local arm rig so it never competes with or replicates through the live character Animator. |
| 2026-10-22 | HRush_TagThirdPerson replacement (`rbxassetid://132133679924288`) | Animation | Exact published ID supplied by project owner | Owner provenance confirmation pending | Replicated tag action (`Config.Tag.ThirdPersonAnimationId`) | Pending Review | Replaces `139144393566205`; server plays it on the character Animator. Owner reported granting this experience asset access on 2026-10-24 after Studio denied it; playback and arm-only blending still await owner Studio verification. |
| 2026-10-18 | HRush_TagThirdPerson (`rbxassetid://139144393566205`) | Animation | Exact published ID supplied by project owner | Owner provenance confirmation pending | Former replicated tag action | Superseded | Replaced by `132133679924288` on 2026-10-22. |

### Pounce integration, 2026-10-16

| Date Added | Asset Name | Type | Source | License | Area Used | Status | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-16 | HRush_PounceWindup (`rbxassetid://112019342280579`) | Animation | Exact published ID supplied by project owner | Owner provenance confirmation pending | Removed pounce mechanic | Superseded | Removed from the runtime on 2026-10-18. |
| 2026-10-16 | HRush_PounceLeap (`rbxassetid://94945585012531`) | Animation | Exact published ID supplied by project owner | Owner provenance confirmation pending | Removed pounce mechanic | Superseded | Removed from the runtime on 2026-10-18. |
| 2026-10-16 | HRush_PounceTag (`rbxassetid://88403484239291`) | Animation | Exact published ID supplied by project owner | Owner provenance confirmation pending | Removed pounce mechanic | Superseded | Replaced by the first-person and third-person tag animations on 2026-10-18. |
| 2026-10-16 | HRush_PounceRecovery (`rbxassetid://115358409009409`) | Animation | Exact published ID supplied by project owner | Owner provenance confirmation pending | Removed pounce mechanic | Superseded | Removed from the runtime on 2026-10-18. |
| 2026-10-16 | Pounce dust, wind ribbons, streaks, impact flash and ring | Procedural VFX | Original Luau in PounceEffects.lua, generated with Codex | Original project source | Removed pounce presentation | Superseded | Removed with PounceEffects.lua on 2026-10-18. |


| Date Added | Asset Name | Type | Source | License | Area Used | Status | Notes |
|------------|-----------|------|--------|---------|-----------|--------|-------|
| 2026-10-18 | HRush_Sprint replacement (`rbxassetid://74829353930740`) | Animation | Exact published ID supplied by project owner | Owner provenance confirmation pending | Sprint animation (`Config.Animations.Sprint`) | Pending Review | Replaces 132688446420207; integrated as requested; not modified or republished. |
| 2026-10-18 | HRush_JumpStart replacement (`rbxassetid://74307357863566`) | Animation | Exact published ID supplied by project owner | Original, project-owned | Jump takeoff animation (`Config.Animations.JumpStart`) | Approved | Replaces 115591963738630; owner-confirmed; integrated as requested; not modified or republished. |
| 2026-10-18 | HRush_Fall replacement (`rbxassetid://84863749801510`) | Animation | Exact published ID supplied by project owner | Original, project-owned | Airborne animation (`Config.Animations.Fall`) | Approved | Replaces 106234834891508; owner-confirmed; integrated as requested; not modified or republished. |
| 2026-10-18 | HRush_Land replacement (`rbxassetid://88319270506819`) | Animation | Exact published ID supplied by project owner | Original, project-owned | Soft landing animation (`Config.Animations.Land`) | Approved | Replaces 83446879560399; owner-confirmed; integrated as requested; not modified or republished. |
| 2026-10-18 | HRush_LandHard replacement (`rbxassetid://104821646839230`) | Animation | Exact published ID supplied by project owner | Original, project-owned | Hard landing animation (`Config.Animations.LandHard`) | Approved | Replaces 93067099789487; owner-confirmed; integrated as requested; not modified or republished. |
| 2026-10-15 | HRush_Walk (`rbxassetid://89956272220101`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Movement animation (`Config.Animations.Walk`) | Approved | Batch A ID supplied by project owner. |
| 2026-10-15 | HRush_Sprint (`rbxassetid://132688446420207`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Sprint animation (`Config.Animations.Sprint`) | Superseded | Replaced 2026-10-18 by 74829353930740; kept for history. |
| 2026-10-15 | HRush_JumpStart (`rbxassetid://115591963738630`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Movement animation (`Config.Animations.JumpStart`) | Superseded | Replaced 2026-10-18 by 74307357863566; kept for history. |
| 2026-10-15 | HRush_Fall (`rbxassetid://106234834891508`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Movement animation (`Config.Animations.Fall`) | Superseded | Replaced 2026-10-18 by 84863749801510; kept for history. The old ID reported 0.25-second, Action, non-looping published metadata. |
| 2026-10-15 | HRush_Land (`rbxassetid://83446879560399`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Movement animation (`Config.Animations.Land`) | Superseded | Replaced 2026-10-18 by 88319270506819; kept for history. |
| 2026-10-15 | HRush_LandHard (`rbxassetid://93067099789487`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Movement animation (`Config.Animations.LandHard`) | Superseded | Replaced 2026-10-18 by 104821646839230; kept for history. |
| 2026-10-15 | HRush_SlideEnter (`rbxassetid://89876839852879`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Movement animation (`Config.Animations.SlideEnter`) | Approved | Batch B ID supplied by project owner. |
| 2026-10-15 | HRush_SlideLoop (`rbxassetid://106056699835668`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Slide animation (`Config.Animations.SlideLoop`) | Approved | Batch B ID supplied by project owner; replaces the combined legacy slide ID. |
| 2026-10-15 | HRush_SlideExit (`rbxassetid://110417300002501`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Movement animation (`Config.Animations.SlideExit`) | Approved | Batch B ID supplied by project owner. |
| 2026-10-15 | HRush_SlideJump (`rbxassetid://77860783763073`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Movement animation (`Config.Animations.SlideJump`) | Approved | Batch B ID supplied by project owner. |
| 2026-10-15 | HRush_Dash (`rbxassetid://118315275767975`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Dash animation (`Config.Animations.Dash`) | Approved | Batch B ID supplied by project owner; replaces the legacy dash ID. |
| 2026-10-16 | HRush_Roll (`rbxassetid://97323662606589`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Roll animation (`Config.Animations.Roll`) | Approved | Batch C ID supplied by project owner. Studio verified 0.45-second, Action, non-looping metadata. |
| 2026-10-16 | HRush_Vault (`rbxassetid://88476053772200`) | Animation | Original pose data in `tools/AnimationDev/HRush_AnimDev.lua` | Original, project-owned | Vault animation (`Config.Animations.Vault`) | Approved | Batch D ID supplied by project owner. Studio verified seven keyframes, 0.40-second duration, Action priority, and non-looping metadata. |
| 2026-10-14 | dash whoosh (`assets/sfx/dash.mp3`, `rbxassetid://139674215369268`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Dash SFX (`Config.Movement.DashSoundId`) | Superseded | Replaced 2026-10-14 by Pixabay whoosh below; kept for history. |
| 2026-10-14 | dash whoosh (`rbxassetid://115548807322300`) | Audio | Pixabay Sound Effects | Royalty-free (Pixabay Content License: free commercial use, no attribution required; allowed under Rule B.6) | Dash SFX (`Config.Movement.DashSoundId`) | Pending Review | Replaces 139674215369268. Needs one team member review to mark Approved (protocol §6). |
| 2026-10-14 | earlier BGM (`rbxassetid://94984747143473`) | Audio | TBD (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Lobby-only BGM loop (`Config.Audio.Music.lobby`, `MusicController`) | Pending Review | Kept for MS_01 after the match track changed. Must confirm license before submission (Rule B.6). |
| 2026-10-25 | match BGM (`rbxassetid://106317705738449`) | Audio | ID supplied by project owner; origin unconfirmed | TBD (confirm original or royalty-free with competition license) | Match-only BGM loop (`Config.UI.MatchIntro.BgmId`, `MusicController`) | Pending Review | Used for voting, RPS, countdown, live rounds and results. Owner granted experience access and confirmed Studio playback on 2026-10-25; license still needs confirmation before submission. |
| 2026-10-14 | UI click (`rbxassetid://89121173273417`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | UI clicks (`Config.Sfx.UI.click`) | Pending Review | Batch 1 SFX. Must confirm license before submission (Rule B.6). |
| 2026-10-14 | UI toggle (`rbxassetid://130394308198775`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Settings toggle (`Config.Sfx.UI.toggle`) | Pending Review | Batch 1 SFX. Must confirm license before submission (Rule B.6). |
| 2026-10-14 | UI slider end (`rbxassetid://134203145736891`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Slider release (`Config.Sfx.UI.sliderEnd`) | Pending Review | Batch 1 SFX. Must confirm license before submission (Rule B.6). |
| 2026-10-14 | queue cancel (`rbxassetid://120812370100773`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Matchmaking cancel (`Config.Sfx.UI.queueCancel`) | Pending Review | Batch 1 SFX. Must confirm license before submission (Rule B.6). |
| 2026-10-14 | match found (`rbxassetid://127385873459389`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Match built (`Config.Sfx.UI.matchFound`) | Pending Review | Batch 1 SFX. Must confirm license before submission (Rule B.6). |
| 2026-10-14 | countdown tick (`rbxassetid://84745673202062`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | MS_03 tick (`Config.Sfx.Countdown.tick`) | Pending Review | Batch 1 SFX. Must confirm license before submission (Rule B.6). |
| 2026-10-14 | countdown go (`rbxassetid://123128040491688`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | MS_03 launch (`Config.Sfx.Countdown.go`) | Pending Review | Batch 1 SFX. Must confirm license before submission (Rule B.6). |
| 2026-10-14 | tag slap (`rbxassetid://138862668790692`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Tag confirm (`Config.Sfx.Tag.slap`) | Pending Review | Batch 1 SFX. Must confirm license before submission (Rule B.6). |
| 2026-10-14 | footstep (`rbxassetid://75359803824642`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Sprint footstep (`Config.Sfx.Movement.footstep`) | Superseded | Replaced 2026-10-15 by 139613878484113; kept for history. |
| 2026-10-15 | footstep (`rbxassetid://139613878484113`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Sprint footstep (`Config.Sfx.Movement.footstep`) | Pending Review | Replaces 75359803824642. Must confirm license before submission (Rule B.6). |
| 2026-10-14 | stamina empty (`rbxassetid://81474882182684`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Stamina cue (`Config.Sfx.Movement.staminaEmpty`) | Pending Review | Batch 2 SFX. Must confirm license before submission (Rule B.6). |
| 2026-10-14 | slide whoosh (`rbxassetid://75817307201002`) | Audio | Team-provided (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Slide SFX (`Config.Movement.SlideSoundId`) | Pending Review | Batch 2 SFX. Must confirm license before submission (Rule B.6). |

---

## Asset Review Protocol

1. **Before importing any Toolbox asset:** Check creator name, asset license, and whether it is explicitly allowed under the Level Up 3.0 rules.
2. **Audio:** Only original audio or royalty-free with confirmed competition license. Log every file.
3. **Models:** Must be original or created by the team. No anonymous Toolbox uploads.
4. **Textures/Decals:** Same as models. Log Roblox stock textures by asset ID.
5. **Fonts:** Log all third-party fonts with license source.
6. **Review:** At least one team member other than the importer must mark Status = Approved.

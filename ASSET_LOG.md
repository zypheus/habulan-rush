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
| 2026-10-18 | HRush_TagThirdPerson (`rbxassetid://139144393566205`) | Animation | Exact published ID supplied by project owner | Owner provenance confirmation pending | Replicated tag action (`Config.Tag.ThirdPersonAnimationId`) | Pending Review | Loaded and played by the server so the tagging player and observers receive the same third-person action. |

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
| 2026-10-14 | match BGM (`rbxassetid://94984747143473`) | Audio | TBD (origin unconfirmed) | TBD (confirm original or royalty-free with competition license) | Match BGM loop (`Config.UI.MatchIntro.BgmId`, `LobbyUI` loading cover) | Pending Review | Loops while in match, fades out on lobby return. Must confirm license before submission (Rule B.6). |
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

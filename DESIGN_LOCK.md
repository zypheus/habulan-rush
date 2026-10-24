# Habulan Rush — Design Lock Sign-off
_Locked: 2026-10-07 | GDD v2.0 Baseline_

All HIGH-severity findings from the GDD System Review are confirmed below.
These values are the single source of truth; they must match `ReplicatedStorage.Config`.

---

## Confirmed Findings (HIGH severity)

### Earned sprint balance revision, 2026-10-24

The project owner approved removing stamina and manual sprint. In live rounds, both roles earn a three-second automatic sprint after two server-accepted slides or landing rolls within 2.5 seconds. Further accepted actions in that chain refresh the sprint. A slide needs server-observed speed of at least half the role's walk speed to count; dash never counts. The timer starts when the qualifying action ends. Role transfer, stun, death, respawn, and round end reset the chain and sprint. The lobby uses walking speed.

Runner base walk and sprint remain 16 and 21; Taya base walk remains 18. Taya base sprint is now 22, or 26.4 studs/s with the existing 1.2 scale. Runner-only dash keeps its 12-stud base distance and 0.2-second travel, with a five-second cooldown and no stamina cost. This revision supersedes earlier held-sprint, stamina, Taya sprint, and dash cooldown rules below and in the baseline specification. The post-tag 20% speed boost remains.

### Reduced pounce cooldowns and airborne fix, 2026-10-17

The owner requested shorter pounce cooldowns and a fix for midair activation. Hit cooldown is now 0.8 seconds and miss cooldown is 1.05 seconds, both measured from launch. These supersede the earlier 1.6/2.1 values. Airborne movement eligibility and launch direction use existing horizontal momentum because the normal air controller clears Humanoid.MoveDirection. Stationary jumps without horizontal movement do not qualify. Recovery timings and incompatible-state gates remain unchanged.

### Approved pounce-only tagging revision, 2026-10-17

This owner-approved revision supersedes the grounded/sprint-only activation restriction below and TM_08 touch tagging. Pounce requires forward movement and may start while walking, sprinting, or normally jumping. Standing still does not qualify. Only a successful validated pounce hit transfers Taya between participants, including bots. Bot Tayas use the same pounce cooldown and hit rules. Touch alone never tags. Existing incompatible-ability, stun, recovery, safe-window and cooldown rules remain.


### Approved pounce revision, 2026-10-16

The project owner approved the pasted Pounce / Tag request and explicitly approved replacing the old locked pounce timings and adding faster Taya sprint. This revision supersedes the original TM_01 sprint restriction and TM_04 through TM_07 pounce values. `Config.Pounce` is the runtime source of truth.

- Taya base walk remains 18. Held sprint is 21 base, or 25.2 studs/s after the existing 1.2 movement scale. Taya has no sprint stamina drain.
- Pounce windup is 0.07 seconds. Hit/miss recovery is 0.15/0.28 seconds; launch-based cooldown is 1.6/2.1 seconds.
- Pounce velocity is 55 horizontal and 13 upward studs/s, with 0.12 steering and a 0.70-second flight limit. These are final world-space velocities, not multiplied by the normal movement scale.
- Server spatial hitbox is 5 by 5 by 6 studs with a 40-degree forward cone. Initial soft assistance is limited to 14 studs, 18 degrees, and strength 0.10.
- Pounce is Taya-only, grounded, and requires forward sprint. Each accepted attempt can commit one tag. Existing safe windows and dash pounce immunity still apply.

| # | Finding | Confirmed Default | Status |
|---|---------|-------------------|--------|
| F01 | Pre-round selection | **MS_02 retired; MS_RPS bato bato pick runs before MS_03 each round** | Owner review |
| F06 | Safe Window stacking | **Windows do not stack; longest remaining applies** | ✅ Confirmed |
| F07 | Dash pounce invulnerability | **0.15 s, vs pounce lunge only** (not Tsinelas Throw or touch tag) | ✅ Confirmed |
| F11 | Close chase distance | **10 studs** (for Diskarte close-chase-escape reward) | ✅ Confirmed |
| F12 | Counter table | See §Counter Table below | ✅ Confirmed |
| F16 | Esports 40–60% metric | **Pounce success rate = hits ÷ attempts** (logged in Playtest Log) | ✅ Confirmed |
| F18 | Disconnect / min players | **Queued search can start a solo sandbox; Taya disconnect during MS_04 still promotes the nearest Runner. Leavers rank last for the round.** | Owner review |

## Counter Table (F12) — Diskarte "Counter" Gain Triggers

| Skill | Counter Condition |
|-------|------------------|
| RS_01 Luksong Baka | Runner escapes a pounce or Lambat while airborne |
| RS_02 Pekeng Takbo | Taya locks onto or pounces the decoy |
| RS_03 Tsinelas Throw | Hit on Taya mid-wind-up or mid-skill cast |
| TS_01 Sigaw | Taya tags a Runner who used Pekeng Takbo within the reveal window |
| TS_02 Lambat | Taya tags a Runner slowed by the net |
| TS_03 Hatak | Taya tags a Runner within 2 s of using Hatak |

## MED Severity Confirmed Defaults

| # | Default Adopted |
|---|----------------|
| F02 | Round 3 "longer focus" = presentation emphasis only; no timing change |
| F03 | Rounds 2–3 identical mechanics; vary event intensity and music only |
| F04 | Tied Taya Time → share rank and points; match tie-break = total Taya time |
| F08 | +20% post-tag boost multiplies base walk (16) and sprint (21) speeds; stamina rules unchanged |
| F09 | Slide hitbox = 50% height; touch tag cannot hit a sliding Runner under a low gap |
| F10 | Hatak disables lock during its 1.5 s only; lock cooldown does not start from Hatak |
| F13 | Same pair cannot grant each other Diskarte more than once per 6 s |
| F14 | No ultimate in MVP; Diskarte activated via F (PC) / mobile button / console face button |
| F15 | Events last until round end unless map spec says otherwise; flood is monotonic |
| F17 | Rewind = Config value; default 0.12 s, cap 0.20 s; log all disputed tags |

## GDD v2.0 Baseline — Strong Rules (Do Not Change)

- Server-authoritative tagging; client owns input, server owns truth.
- Counter triangle: Escape / Area / Detection; no skill guarantees a tag or escape.
- Diskarte: per-round, non-passive, temporary effect resource.
- Tutorial and core loop are never cut for stretch features.

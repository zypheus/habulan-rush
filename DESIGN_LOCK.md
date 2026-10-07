# Habulan Rush — Design Lock Sign-off
_Locked: 2026-10-07 | GDD v2.0 Baseline_

All HIGH-severity findings from the GDD System Review are confirmed below.
These values are the single source of truth; they must match `ReplicatedStorage.Config`.

---

## Confirmed Findings (HIGH severity)

| # | Finding | Confirmed Default | Status |
|---|---------|-------------------|--------|
| F01 | Skill Draft frequency | **Draft runs before every round** (adds 24 s; target match = 9.0 min) | ✅ Confirmed |
| F06 | Safe Window stacking | **Windows do not stack; longest remaining applies** | ✅ Confirmed |
| F07 | Dash pounce invulnerability | **0.15 s, vs pounce lunge only** (not Tsinelas Throw or touch tag) | ✅ Confirmed |
| F11 | Close chase distance | **10 studs** (for Diskarte close-chase-escape reward) | ✅ Confirmed |
| F12 | Counter table | See §Counter Table below | ✅ Confirmed |
| F16 | Esports 40–60% metric | **Pounce success rate = hits ÷ attempts** (logged in Playtest Log) | ✅ Confirmed |
| F18 | Disconnect / min players | **Min 4 players. Taya disconnect → nearest Runner becomes Taya. Leavers rank last for the round.** | ✅ Confirmed |

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

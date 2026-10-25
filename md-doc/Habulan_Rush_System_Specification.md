# **HABULAN RUSH System Specification** 

_Version 1.0 • Derived from GDD v2.0 • Items tagged [SD] are spec defaults pending confirmation_ 

## **1. Purpose and scope** 

This document turns GDD v2.0 into implementable rules. It defines state, rules, formulas, edge cases and acceptance criteria for each gameplay system. Numeric values live in Config (see Balance Workbook); this document refers to them by name. 

## **2. Match flow system** 

|**State**|**Entry condition**|**Exit condition**|**Server actions**|
|---|---|---|---|
|MS_01 Lobby|Server start / match end|Queued search times out or reaches 8 players; solo sandbox allowed|Start queued match|
|MS_VOTE Map Vote|Queued match starts|Vote timer ends|Collect map votes and publish the selected map|
|MS_RPS Bato Bato Pick|Map vote or Round End ends; at least two players remain eligible|One starting Taya remains, or stage cap is reached|Run server-timed pick, reveal, and elimination stages; publish starting Taya|
|MS_03 Match opening and countdown|MS_RPS ends, or one eligible player skips it|19 s preparation ends in round one; 5 s countdown ends in later rounds|Spawn players, use the MS_RPS result as first Taya, lock movement; show five 2 s Kalsada landmark clips, a 3.5 s avatar lineup and 0.5 s handoff once per match before the 5 s countdown|
|MS_04 Round Live|Countdown ends|Timer reaches 0|Run Taya Timer, Diskarte, events,<br>phases|
|MS_05 Round End|Round Live ends|8 s timer ends|Freeze input, rank, award points,<br>recap|
|MS_06 Match End|After round 3|15 s timer ends|Final ranking, MVP, return to lobby|



### **2.1 First Taya (bato bato pick)**

- The match-long eligible pool starts with every match player. Remove a player only after they start as Taya. Refill from all present players when empty. If the pool has one player, skip MS_RPS and choose that player.

- In MS_RPS, only eligible players submit Rock, Paper, or Scissors. The server accepts one valid sign per player per stage during the pick window and randomizes missing choices. Clients receive the roster and deadline, then a simultaneous sign reveal. A player sees only their own sign before reveal.
- One sign or all three signs is a tie: repeat with the same stage pool. With exactly two signs, players showing the winning sign leave the stage pool as safe; the losing sign stays. After Config.Match.Rps.MaxStages stages, randomly choose from the remaining stage pool and announce SUDDEN PICK.
- A disconnected player leaves the stage pool. One remaining player starts as Taya. If none remain, draw from the shuffle bag of present players as a fallback. A late joiner is not added until the next match [SD].
- Config.Match.Rps owns intro, pick, reveal, resolve, result, and Studio timings. The server owns the pool, deadlines, signs, resolution, and starting Taya. RpsStageStart, RpsReveal, and RpsResult are server-to-client; RpsSubmitSign is client-to-server.

### **2.2 Scoring** 

- Taya Timer increases only while the player is Taya, tracked server-side in tenths of a second. 

- Round rank: ascending Taya Time. Ties share rank and points [SD]. Points 8-6-5-4-3-2-1-0 by rank. 

- Match winner: highest total points; tie-break lowest total Taya Time. 

- A player who leaves mid-round is ranked last for that round [SD]. 

## **3. Movement system** 

|**Rule**|**Specification**|
|---|---|
|Runner speed|Walk 16, earned sprint 21 studs/s before the 1.2 speed scale. Two accepted slides or landing rolls within 2.5 s grant a 3 s automatic sprint [owner revision 2026-10-24].|
|Stamina|Removed. Sprint and Runner dash have no stamina cost [owner revision 2026-10-24].|
|Dash|12 studs in 0.2 s, 5 s cooldown, 0.15 s tag-action invulnerability [SD]. Runner-only; does not count toward the sprint chain.|
|Slide|1.0 s, 1.25 s cooldown from entry, reduced hitbox (50% height) [SD]. A server-accepted slide counts toward earned sprint when observed speed is at least half the role's walk speed, even without momentum gain.|



Habulan Rush • System Specification • Page 1 

|**Rule**|**Specification**|
|---|---|
||tags cannot hit a Runner passing a low gap.|
|Taya speed|Walk 18, earned sprint 22 studs/s before the 1.2 speed scale. Uses the same chain rule as Runner [owner revision 2026-10-24].|
|Post-tag boost|Ex-Taya: +20% on base walk and sprint speed for 2 s [SD].|



## **4. Tagging system** 

### **4.1 Valid tag** 

The server accepts a tag only if all hold: requester is Taya; state is Round Live; Taya is not stunned; target is a Runner without an active Safe Window; distance and line-of-sight pass at the rewound target position; and Lock Delay does not apply to touch/pounce (it only gates target lock). 

|**Tag type**|**Condition**|**Notes**|
|---|---|---|
|Touch tag|Within 3 studs while Taya is moving|Reliable backup tag|
|Pounce|0.35 s wind-up, then 14-stud lunge at 45<br>studs/s, hit radius 4|Miss = 1.0 s self-stun; cooldown 3 s|



### **4.2 Tag transfer sequence** 

- Tagged Runner becomes Taya immediately; previous Taya becomes Runner. 

- Previous Taya: 2 s Safe Window and 2 s +20% speed boost. 

- New Taya: 1 s Lock Delay (touch and pounce still allowed). 

- Fire one TagEvent (tagger id, target id, timestamp) to all clients and spectators. 

- Safe Windows from different sources do not stack; the longest remaining applies [SD]. 

### **4.3 Target lock** 

- Acquire within 40 studs with line of sight; break beyond 55 studs. 

- Lock breaks on qualifying dash, entering cover, or 1 s out of line of sight; then 4 s lock cooldown. 

- Lock never moves the Taya; it only assists camera aim. 

## **5. Skill system** 

|**ID**|**Skill**|**Role / type**|**CD**|**Server rule**|**Counter (for Diskarte**<br>**"counter")**|
|---|---|---|---|---|---|
|RS_<br>01|Luksong<br>Baka|Runner /<br>Escape|12 s|Impulse to 14 studs high, 18<br>distance; no air steering|Escapes a pounce or Lambat<br>while airborne|
|RS_<br>02|Pekeng<br>Takbo|Runner / Decoy|18 s|Decoy runs 4 s; can break lock|Taya locks or pounces the<br>decoy|
|RS_<br>03|Tsinelas<br>Throw|Runner / Stun|25 s|Projectile up to 25 studs; stuns<br>Taya 1 s on hit|Hit on Taya mid-wind-up or<br>mid-skill|
|TS_0<br>1|Sigaw|Taya / Detection|20 s|Reveal Runners within 40 studs<br>for 2 s|Tag a Runner who used<br>Pekeng Takbo within the<br>reveal|
|TS_0<br>2|Lambat|Taya / Area|22 s|Radius 8, −40% speed for 5 s|Tag a Runner slowed by the<br>net|
|TS_0<br>3|Hatak|Taya / Speed|15 s|+35% for 1.5 s, lock disabled<br>during effect|Tag within 2 s of using it|



- Draft: 2 offered per slot, 1 chosen per slot; offers are random, outcomes are not. A player who does not pick receives a random offered skill. 

- Cooldowns are server timers that persist through role changes; skill slot of the inactive role is unusable. 

Habulan Rush • System Specification • Page 2 

- Skill requests are rejected if state is not Round Live, role mismatch, cooldown active, or player is stunned. 

## **6. Diskarte system** 

- Meter 0–100, per player, resets to 0 at round start and after a Move is activated. No passive gain. 

- Gains (Config): Runner lock-break 15, pounce dodge 25, counter 20, close-chase escape 15 (within 10 studs [SD]). Taya pounce 25, tag 15, catch after escape skill 20, counter 20. 

- Anti-snowball: no gain for repeated tags on the same player within 3 s; the same two players cannot grant each other gains more than once per 6 s [SD]. Idle movement never grants Diskarte. 

- Activation: F key / mobile button / console face button [SD]; only at 100. A Move is selected from the player's role set. 

|**Move**|**Role**|**Effect**|**Limits**|
|---|---|---|---|
|LIKSI|Runner|Next Runner skill within 8 s has 50% cooldown reduction|One use; expires at 8 s|
|BANTAY|Taya|Directional clue to nearest Runner in range for 2 s|No wall reveal|
|PUSO|Both|0.75 s Safe Window after next valid tag interaction|One trigger; expires at 10 s;<br>does not stack with other<br>windows|



## **7. Barangay Rush and Huling Habol** 

|**Time left**|**Phase**|**Rule**|
|---|---|---|
|150–100 s|SIMULA|Normal play|
|100–50 s|BARANGAY RUSH|Map event triggers at 100 s with a 2–3 s warning banner; effect lasts<br>until round end unless the map says otherwise [SD]|
|50–0 s|HULING HABOL|Presentation escalation at 50, 30, 15, 10, 5 s; no stat changes|



- Event rules: telegraphed, decision-changing, spectator-readable, never removes a player from the match, always leaves a counter-route. 

- Kalsada — Court Rush: basketball court opens as a fast open shortcut with no cover. 

- Binaha — Tubig Tumataas: water rises in steps; low zones slow movement; evacuation zones grant a short Safe Window (value in Config) once per visit. 

- Recycling Hub (stretch) — Linis Barangay: recyclable pickup point alters routing; reward must be cosmetic or Diskarte-neutral. 

## **8. Edge cases** 

|**Case**|**Behavior**|
|---|---|
|Taya disconnects|Nearest Runner becomes Taya; timer continues for the new Taya|
|Runner disconnects|Removed from play; ranked last for the round|
|Players below 4|Pause round for 10 s, then end round without awarding points [SD]|
|Simultaneous tags|Earliest server timestamp wins; ties resolved by lowest user id|
|Round ends mid-pounce|Pounce result is discarded; tags after 0 s are rejected|
|Skill used on tag frame|Server processes in arrival order; tag transfer wins over cooldown start|



## **9. Acceptance criteria** 

- Every rule above is represented by a Config key or a server check. 

- Each system passes the relevant test case in the QA Test Plan. 

- No client-reported hit, cooldown or score is trusted. 

Habulan Rush • System Specification • Page 3 


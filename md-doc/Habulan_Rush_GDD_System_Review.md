# **HABULAN RUSH GDD System Review** 

_Review of GDD v2.0 • Prepared Oct 2026 • Purpose: find gaps before Design Lock sign-off_ 

## **1. Summary** 

The GDD v2.0 is coherent and well scoped. The core loop (Tag → Taya Timer → rank) is clear, the three signature systems (Diskarte, Barangay Rush, Huling Habol) layer on top without changing the core, and the MVP/stretch split is sound. This review lists 18 gaps that would otherwise be decided ad hoc during implementation, each with a recommended default. Items marked HIGH should be confirmed at Design Lock; the defaults are already used in the System Specification and Balance Workbook. 

### **1.1 System health at a glance** 

|**System**|**Clarity**|**Risk**|**Verdict**|
|---|---|---|---|
|Match state machine & scoring|High|Low|Ready; clarify draft frequency and ties|
|Movement & tagging|High|Medium|Ready; Taya edge over cycling Runner is very small<br>(see §3)|
|Skill Draft & 6 skills|Medium|Medium|Small pool; counters are clear but untested|
|Diskarte|Medium|High|Several undefined triggers; snowball guard is thin|
|Barangay Rush|Medium|Medium|Only 1 event fully defined per map; duration<br>undefined|
|Huling Habol|High|Low|Presentation-only; safe to build|
|Esports / spectator|Medium|Medium|Metric for the 40–60% target is undefined|
|Technical design|High|Medium|Lag compensation window may be too small for<br>mobile|



## **2. Findings** 

|**#**|**Area**|**Finding**|**Severit**<br>**y**|**Recommended default**|
|---|---|---|---|---|
|F01|Match<br>flow|MS_02 Skill Draft is listed once; unclear<br>whether it repeats each round. Diskarte<br>resets each round, and rounds are meant<br>to feel different.|HIGH|Draft before every round (adds 24 s; match<br>= 9.0 min, inside 8–10).|
|F02|Rounds|Round 3 "longer focus on the final chase"<br>conflicts with fixed 150 s rounds.|MED|Presentation emphasis only; no change to<br>timing or stats.|
|F03|Rounds|Rounds 2 and 3 have no mechanical<br>difference besides map event emphasis.|MED|Keep stats identical; vary event intensity<br>and music only.|
|F04|Scoring|Ties in Taya Time within a round are not<br>handled.|MED|Tied players share the rank and points;<br>match tie-break is total Taya time.|
|F05|Scoring|Points table has 8 slots; matches run 4–8<br>players. Smaller lobbies make 1st worth<br>the same 8 points.|LOW|Keep table; use top-N slots only. Note in<br>tournament rules.|
|F06|Tagging|Safe Window (2 s), PUSO Safe Window<br>(0.75 s) and Dash invulnerability can<br>overlap; stacking is undefined.|HIGH|Windows do not stack; the longest<br>remaining one applies.|
|F07|Moveme|Dash grants "brief pounce invulnerability"|HIGH|0.15 s, vs pounce only (not Tsinelas Throw|



Habulan Rush • GDD System Review • Page 1 

|**#**|**Area**|**Finding**|**Severit**<br>**y**|**Recommended default**|
|---|---|---|---|---|
||nt|with no duration.||or touch tag).|
|F08|Moveme<br>nt|Post-tag +20% speed boost: base speeds<br>or current speed? Interaction with<br>stamina unclear.|MED|Multiplies base walk and sprint; stamina<br>rules unchanged.|
|F09|Tagging|Slide "tiny hitbox" has no numeric value;<br>touch tag range is 3 studs.|MED|Slide hitbox height 50%; touch tag cannot<br>hit a sliding Runner under a low gap.|
|F10|Lock|Lock Delay (1 s), lock cooldown (4 s) and<br>Hatak (lock disabled) can chain into long<br>no-lock windows.|MED|Hatak disables lock only during its 1.5 s;<br>lock cooldown does not start from Hatak.|
|F11|Diskarte|"Close chase distance" and "close range"<br>(Perfect Escape) are undefined.|HIGH|10 studs.|
|F12|Diskarte|"Successful counter skill" has no<br>definition (e.g. Sigaw reveal escaped?<br>Tsinelas hit?).|HIGH|Publish a counter table in the System Spec<br>(§5 there).|
|F13|Diskarte|Anti-snowball only blocks repeated tags<br>on the same player within 3 s. Pounce-<br>dodge farming between two cooperating<br>players is possible.|MED|Same pair cannot grant Diskarte more than<br>once per 6 s.|
|F14|UI|Skill bar mentions "ultimate if enabled";<br>no ultimate exists. Diskarte Move<br>activation input is undefined.|MED|Remove ultimate from MVP. Activate with<br>F (PC), button next to skill bar (mobile),<br>face button (console).|
|F15|Rush|Event duration and end state are<br>undefined (does Court Rush reset?).|MED|Events last until round end unless the map<br>spec says otherwise; flood is monotonic.|
|F16|Esports|"Taya win / Runner survival 40–60%" has<br>no measurable definition.|HIGH|Use pounce success rate = hits ÷ attempts<br>(Balance Workbook, Playtest Log).|
|F17|Technical|0.1 s rewind may not cover Roblox<br>mobile latency; fast pounce (45 studs/s)<br>moves 4.5 studs in 0.1 s.|MED|Make rewind a Config value (default 0.12<br>s, cap 0.2 s); log disputed tags.|
|F18|Operatio<br>ns|No rules for disconnect, late join, or fewer<br>than 4 players; shuffle bag with changing<br>roster undefined.|HIGH|Min 4 players. On Taya disconnect,<br>nearest Runner becomes Taya. Leavers<br>rank last for the round.|



## **3. Balance observations from the Balance Workbook** 

- A Runner who sprints until empty and recovers averages about 17.7 studs/s versus Taya at 18, so Taya gains only about 0.26 studs/s over a full stamina cycle. Straight-line chases are therefore decided by skills, dashes, vaults and routes, which matches design intent, but test that Taya does not feel hopeless on open maps. 

- A pounce has 18 studs of effective reach (14 + 4 radius) while a dash covers 12. Dash alone does not escape a pounce, so dodging requires timing. This supports the Pounce Dodge Diskarte reward. 

- A pounce commits about 0.66 s and costs about 1.66 s total on a miss, which is a strong deterrent against spamming. Hatak at +35% reaches 24.3 studs/s, 3.3 above sprint, and lasts only 1.5 s. 

- Match length with draft every round is 540 s (9.0 min). With draft once it is 456 s (7.6 min), below the 8-minute target. 

## **4. Items that are strong and should not change** 

- Server-authoritative tagging and the "client owns input, server owns truth" rule. 

- Counter triangle (Escape / Area / Detection) and the rule that no skill guarantees a tag or escape. 

- Diskarte as a per-round, non-passive, temporary-effect resource. 

Habulan Rush • GDD System Review • Page 2 

- Scope lock: tutorial and core loop are never cut for stretch features. 

## **5. Recommended sign-off checklist** 

- Confirm defaults for F01, F06, F07, F11, F12, F16, F18 at Design Lock (Oct 7–8). 

- Copy confirmed values into Config and the Balance Workbook (rows marked SPEC DEFAULT). 

- Re-run the Match Time sheet after any change to draft or round timing. 

Habulan Rush • GDD System Review • Page 3 


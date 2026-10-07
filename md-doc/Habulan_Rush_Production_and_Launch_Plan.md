# **HABULAN RUSH Production & Launch Plan** 

_Version 1.0 • Competition: Level Up 3.0 Esports Game Dev Challenge • Deadline Oct 25, 2026_ 

## **1. Objective** 

Ship a polished, stable Classic Habulan build with Barangay Kalsada and (if stable) Binaha na Baryo, a working tutorial, private lobbies and spectator camera by Oct 25, 2026. "Launch" means the competition submission and demo; there is no monetization. 

## **2. Schedule** 

|**Dates**|**Phase**|**Deliverables**|**Gate**|
|---|---|---|---|
|Oct 7–8|Design lock|GDD v2.0 approved, Config final, roles<br>assigned, repo|Confirm GDD System Review<br>defaults|
|Oct 9–12|Core loop|Match, tag, movement, Taya Timer,<br>scoreboard, Kalsada greybox|Alpha: 3 clean matches|
|Oct 13–15|Skills + Diskarte|Draft, 3+3 skills, Diskarte and Moves|All skills pass 1v1|
|Oct 16–17|Rush systems|Court Rush, Huling Habol, clutch feedback|Beta: all P0 features in|
|Oct 18–19|Second map|Binaha na Baryo only if stable; tutorial and<br>lobby/spectator finish|Go/no-go on map (Oct 18)|
|Oct 20–21|Polish + freeze|Art, UI, sound, performance, tutorial; feature<br>freeze|Freeze Oct 21 evening|
|Oct 22–23|Testing|Six-player playtests, tuning, bug fixes|Release candidate|
|Oct 24|Submission<br>package|Trailer, demo, synopsis, forms, disclosure<br>check|Package review|
|Oct 25|Deadline|Submit final package early in the day|Submitted|



## **3. Team and responsibilities** 

|**Role**|**Responsibilities**|**Count**|
|---|---|---|
|Producer / Lead|Schedule, scope decisions, submission, disclosure log|1|
|Game Designer|Config, balance, event design, playtest analysis|1|
|Programmers|Services, controllers, networking (see TDD)|2|
|UI Developer|HUD, screens, tutorial|1|
|Artist / Builder|Maps, VFX, characters|1–2|
|Audio|Music, SFX, voice|1|
|QA|Test cases, bug tracking, playtest sessions|Shared by all|



Adjust to the real team size; one person may hold several roles. Replace role names with names in the Production Tracker. 

## **4. Scope management** 

|**Priority**|**Items**|**Rule**|
|---|---|---|
|P0 (must)|Classic FFA, 3 rounds, tag + timer, movement, 3+3 skills, Diskarte,|Never cut|



Habulan Rush • Production & Launch Plan • Page 1 

|**Priority**|**Items**|**Rule**|
|---|---|---|
||Barangay Rush, Huling Habol, Kalsada, tutorial, private lobby,<br>spectator camera||
|P1 (should)|Binaha na Baryo, clutch popups and recap, voice lines, mobile layout<br>options|Cut at Day-12<br>checkpoint or freeze if<br>behind|
|P2 (stretch)|Recycling Hub, Palengke, Palayan, Time Trial, Team Habulan, Last<br>Runner Standing, audience voting|Only after freeze if<br>stable; otherwise out|



- Feature freeze Oct 21 evening: after it, only bug fixes, tuning and polish with team approval. 

- Daily 10-minute stand-up; update the Production Tracker at end of day. 

## **5. Risk register** 

|**Risk**|**Impact**|**Prob.**|**Mitigation**|**Owner**|
|---|---|---|---|---|
|Feature creep|High|Med|Scope lock; stretch only after freeze|Producer|
|Tutorial skipped|High|Med|Built by Oct 12 (blockout) and finished before<br>polish|UI Dev|
|Lag disputes|High|Med|Server authority, rewind, logs|Programmer|
|Diskarte snowball|High|Low|Temporary effects; per-round reset; playtest|Designer|
|Asset/AI disclosure<br>issue|High|Low|Source list and AI_LOG.md from day 1; audit Oct<br>24|Producer|
|Team member<br>unavailable|Med|Med|Two people know each module; daily integration|Producer|
|Studio/Roblox outage<br>near deadline|High|Low|Submit by noon Oct 25 and keep a published<br>backup version|Producer|
|Map event feels<br>random|Med|Med|Telegraph; counter-route; spectator test|Designer|



## **6. Launch (submission) plan** 

### **6.1 Submission package** 

|**Item**|**Owner**|**Due**|**Status**|
|---|---|---|---|
|Published game, public or per rules, tested from a clean<br>account|Programmer|Oct 23|☐|
|Gameplay trailer (60–90 s): hook, tag, skills, Diskarte, Rush,<br>Huling Habol, clutch|Artist/Audio|Oct 24|☐|
|Demo plan: 6-player match script, spectator view, private<br>lobby code|Producer|Oct 24|☐|
|Game synopsis: pitch, theme relevance (Philippine games,<br>DRRM, circular economy), esports features|Designer|Oct 24|☐|
|AI / asset disclosure with AI_LOG.md and source list|Producer|Oct 24|☐|
|Entry forms and team details per competition rules|Producer|Oct 24|☐|
|Final submission|Producer|Oct 25 (aim: before<br>noon)|☐|



### **6.2 Go / no-go checklist (Oct 24)** 

- Two consecutive clean 6-player matches on PC and one on mobile. 

- No open Blocker or Major bugs; tutorial completes for new players. 

- Pounce success within 40–60% in the last 3 sessions; match duration 8–10 min. 

Habulan Rush • Production & Launch Plan • Page 2 

- Trailer, synopsis, disclosure and forms complete and reviewed by two people. 

- Published version matches the tested build; backup version saved. 

## **7. Communication and tracking** 

- Tracker: Habulan_Rush_Production_Tracker.xlsx (12-day build window); Balance: Habulan_Rush_Balance_Workbook.xlsx. 

- Stand-up: 10 minutes daily; blockers recorded in the Daily Summary sheet. 

- Decisions about scope are made by the Producer with the Designer; changes recorded in the GDD revision note. 

## **8. Post-submission** 

- Collect judge and audience feedback for the demo; log it against GDD features. 

- Plan stretch items (more maps, modes, audience voting) only after the competition result. 

Habulan Rush • Production & Launch Plan • Page 3 


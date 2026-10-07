Habulan Rush: Game Design Document 

# Habulan Rush: Game Design Document 

Working title: Habulan Rush Target event: Level Up 3.0 Esports Game Dev Challenge (Student Category) Platform: Roblox (PC, mobile, console via Roblox client) Document version: 0.1 (draft for team review) 

## 0. How to read this document 

This document is written for both humans and AI coding agents. 

- Every system has an ID in `CODE_STYLE` (for example `RS_01` , `TS_02` ). Use these IDs in code, commits, and tickets. 

- Every number is a starting value. All numbers live in one config module ( `Config.lua` , see section 13). Never hardcode them. 

- Lines starting with **Plain English** explain the idea without jargon. 

- Items marked **MVP** must exist in the first submission build. Items marked **Stretch** are only built after MVP is stable. 

## 1. Overview 

### 1.1 One line pitch 

A fast Filipino playground chase game where the tagged player becomes the chaser, everyone drafts random skills, and the player who spends the least time as Taya wins. 

### 1.2 What is Habulan 

Habulan is the Filipino game of tag. One player is the Taya (the "it"). The Taya chases the others. When the Taya tags someone, that person becomes the new Taya. 

### 1.3 Key facts 

|Item|Value|
|---|---|
|Genre|Competitive party chase, free for all and team|
|Players per match|4 to 8 (recommended 6)|



Page 1 of 16 

Habulan Rush: Game Design Document 

|Item|Value|
|---|---|
|Round length|150 seconds|
|Match length|3 rounds, about 8 to 10 minutes|
|Camera|Third person, soft target lock for Taya|
|Monetization|None (no Robux purchases, per competition rules)|
|Themes covered|Philippine Games and Sports, Disaster Risk<br>Reduction and Management, Circular Economy,<br>Education|



### 1.4 Design pillars 

1. **Easy to learn:** Chase, escape, tag. A new player understands it in 30 seconds. 

2. **Skill over luck:** Randomness only decides what you can choose from, never who wins. 

3. **Spectator friendly:** Every important moment has a clear sound and visual cue. 

4. **Proudly Filipino:** Names, maps, music, and game ideas come from Philippine street culture. 

## 2. Competition compliance matrix 

|Rule or criterion|Source|How Habulan Rush meets it|
|---|---|---|
|Skill-based match with a clear<br>winner each round|Sec. B.2|Lowest Taya time wins each round,<br>scoreboard shows it live|
|Match completes in a reasonable<br>time|Sec. B.2|150 second rounds|
|Playable without paid license|Sec. B.3|Roblox is free to play, no paid<br>items|
|Not commercially published on<br>major platforms|Sec. B.5|Ask DOST Regional Office to<br>confirm Roblox status (open<br>question OQ1)|
|Original code and mechanics|Sec. B.7|All scripts written by registered<br>team members, no core mechanics<br>from tutorials or templates|



Page 2 of 16 

Habulan Rush: Game Design Document 

|Rule or criterion|Source|How Habulan Rush meets it|
|---|---|---|
|No unlicensed assets|Sec. B.6|Only team-made or licensed<br>assets, no random Toolbox models|
|AI disclosure|Sec. B.8, Form 03|Keep<br>`AI_LOG.md`from day one<br>(section 16)|
|Forms 01, 02, 03, Template 01|Sec. B.11|Checklist in section 15|
|Trailer 1 to 2 min, demo 3 to 5 min<br>(.mp4)|Sec. B.11|Planned in schedule, section 14|
|Philippine culture integration|Screening:<br>Originality|Skills, maps, and audio draw from<br>Filipino games and places|
|Esports Potential 20%|Final judging|Balanced skills, replayable,<br>spectator camera, private lobbies|



Page 3 of 16 

Habulan Rush: Game Design Document 

## 3. Core loop 

### 3.1 Match state machine 

|State<br>ID|State|Duration|What happens|Next|
|---|---|---|---|---|
|MS_01|Lobby|until<br>ready|Players join, pick team or FFA mode,<br>vote map|MS_02|
|MS_02|Skill Draft|12 s|Each player picks 1 Runner skill and 1<br>Taya skill from random choices|MS_03|
|MS_03|Countdown|5 s|Players spawn, Taya is randomly<br>chosen, movement locked|MS_04|
|MS_04|Round Live|150 s|Chase, tag passing, skills, Skill Surge<br>events|MS_05|
|MS_05|Round End|8 s|Show Taya time ranking and points|MS_02 or<br>MS_06|
|MS_06|Match End|15 s|Final ranking, MVP highlight, return<br>to lobby|MS_01|



Plain English: draft your skills, get dropped in, chase for 2.5 minutes, see who spent the least time as the chaser, repeat three times. 

### 3.2 Choosing the first Taya (fair randomness) 

Use a **shuffle bag** : put every player in a bag, draw one at random, and do not draw them again until everyone has been drawn. The bag persists across rounds in the same match. Plain English: it feels random, but nobody gets stuck being Taya first every round. 

### 3.3 Tag passing 

1. Taya successfully tags a Runner (server confirms). 

2. The tagged player becomes Taya immediately. 

3. The old Taya becomes a Runner and gets a 2 second **Safe Window** (cannot be tagged) plus a 2 second speed boost of +20%. 

Page 4 of 16 

Habulan Rush: Game Design Document 

4. The new Taya has a 1 second **Lock Delay** (cannot use target lock), so the old Taya can get away. 

### 3.4 Win condition and scoring 

- Each player has a **Taya Timer** that counts up only while they are Taya. 

- When the round ends, players are ranked by lowest Taya Timer. 

- Ties are broken by fewer times tagged, then by more successful escapes (a Runner who dodges a pounce). 

Round points by rank: 

|Rank|1|2|3|4|5|6|7|8|
|---|---|---|---|---|---|---|---|---|
|Points|8|6|5|4|3|2|1|0|



Match winner is the player with the most points after 3 rounds. Tie break: lowest total Taya time. 

## 4. Movement and chase mechanics 

All values live in `Config.Movement` and `Config.Taya` . 

### 4.1 Runner movement 

|ID|Mechanic|Value|Notes|
|---|---|---|---|
|RM_01|Walk speed|16 studs/s|Roblox default|
|RM_02|Sprint<br>speed|21 studs/s|Hold sprint key|
|RM_03|Stamina|100 max|Drains 20/s while sprinting, regenerates 12/s<br>after 1 s of not sprinting|
|RM_04|Dash|12 studs in 0.2 s|Cooldown 6 s, 0.15 s invulnerable to pounce|
|RM_05|Jump|Roblox default|Can vault low obstacles (height up to 4 studs)|
|RM_06|Slide|0.6 s, tiny<br>hitbox|Only through low gaps, cooldown 3 s|



Page 5 of 16 

Habulan Rush: Game Design Document 

Plain English: Runners are slightly faster than a walking Taya only when sprinting, so they must manage stamina and cannot run forever. 

### 4.2 Taya movement and tagging 

|ID|Mechanic|Value|Notes|
|---|---|---|---|
|TM_01|Taya speed|18 studs/s|No sprint, no stamina|
|TM_02|Soft target<br>lock|Range 40 studs, breaks<br>beyond 55 studs|Needs line of sight, steers<br>camera toward target, does not<br>auto move|
|TM_03|Lock break<br>rules|Target dashes, hides, or<br>leaves line of sight for 1 s|After break, lock cooldown 4 s|
|TM_04|Pounce wind<br>up|0.35 s|Visible crouch animation and<br>sound (the "tell")|
|TM_05|Pounce lunge|14 studs at 45 studs/s|Hit radius 4 studs|
|TM_06|Pounce miss|Taya stunned 1.0 s|Risk and reward|
|TM_07|Pounce<br>cooldown|3 s|Prevents spam|
|TM_08|Basic touch<br>tag|Contact within 3 studs while<br>moving|Backup if pounce is not used|



Plain English: the Taya gets help aiming (soft lock), but a missed pounce leaves them stuck for a second, so wild lunging is punished. 

### 4.3 Server authority 

- The server decides whether a tag, pounce hit, or skill hit counted. 

- The client only sends requests (for example "I want to pounce"). 

- The server checks distance, cooldown, state, and line of sight before accepting. 

- Lag compensation: accept hits within a 0.1 s rewind window using stored positions. 

Plain English: the player's device never decides if they won a tag, which stops cheating and "that did not hit me" arguments. 

Page 6 of 16 

Habulan Rush: Game Design Document 

## 5. Skill system 

### 5.1 Rules 

- Every player owns **2 skill slots** : one Runner skill and one Taya skill. 

- When you are a Runner, your Runner skill is active. When you become Taya, your Taya skill becomes active. 

- Skill Draft (MS_02): show **N random choices** per slot and let the player pick 1. 

   - MVP (3 skills per role): show 2 choices. 

   - Stretch (6 skills per role): show 3 choices. 

- Cooldowns stay between 10 and 25 seconds. 

- Every skill has a **tell** (visible or audible warning) and a **weakness** . 

- No two skills may do the same job. 

Plain English: you always have a plan for both sides of the chase, and the skill list is random only in what is offered, not in who wins. 

### 5.2 Counter triangle 

|Type|Beats|Loses to|
|---|---|---|
|Escape (jump, dash, slide)|Lock on and pounce|Area control|
|Area control (net, barrier)|Escape|Detection or vaulting|
|Detection (reveal, tracking)|Hide and decoy|Escape|



### 5.3 Runner skills 

|ID|Name|Type|Effect|Cooldown|Tell|Weakness|Tier|
|---|---|---|---|---|---|---|---|
|RS_01|Luksong<br>Baka|Escape|Big jump (height 14<br>studs, distance 18<br>studs) over the Taya's<br>reach|12 s|Dust ring<br>and "hup"<br>sound|No air steering,<br>easy to read|MVP|
|RS_02|Pekeng<br>Takbo|Decoy|Leaves a decoy that<br>runs away for 4 s and<br>breaks lock on|18 s|Puff of<br>smoke|Taya can ignore<br>it|MVP|



Page 7 of 16 

Habulan Rush: Game Design Document 

|ID|Name|Type|Effect|Cooldown|Tell|Weakness|Tier|
|---|---|---|---|---|---|---|---|
|RS_03|Tsinelas<br>Throw|Stun|Throws a slipper<br>(range 25 studs),<br>stuns Taya 1 s on hit|25 s|Spinning<br>slipper arc|Can miss,<br>travels slowly|MVP|
|RS_04|Tago|Hide|Invisible and<br>unlockable for up to 3<br>s while standing in<br>cover|20 s|Bush rustle|Cannot move,<br>ends if<br>revealed|Stretch|
|RS_05|Piko<br>Boost|Speed|Places a hopscotch<br>tile, +30% speed for 2<br>s to whoever steps on<br>it|16 s|Chalk tile<br>glow|Tile lasts 8 s,<br>Taya can use it|Stretch|
|RS_06|Palusot|Escape|Slide under gaps, tiny<br>hitbox for 2 s|14 s|Sliding<br>sound|Slow while<br>sliding|Stretch|



### 5.4 Taya skills 

|ID|Name|Type|Effect|Cooldown|Tell|Weakness|Tier|
|---|---|---|---|---|---|---|---|
|TS_01|Sigaw|Detection|Shout reveals all<br>Runners in 40 studs<br>for 2 s|20 s|Loud shout<br>and screen<br>ring|Runners hear it<br>coming|MVP|
|TS_02|Lambat|Area|Drops a net zone<br>(radius 8 studs)<br>slowing Runners by<br>40% for 5 s|22 s|Visible net<br>on ground|Can be jumped<br>over|MVP|
|TS_03|Hatak|Speed|+35% speed for 1.5 s|15 s|Speed lines<br>and whoosh|Target lock<br>disabled while<br>active|MVP|
|TS_04|Sakmal|Pounce|Pounce range +50%|15 s|Claw glow|Miss stun<br>becomes 1.5 s|Stretch|
|TS_05|Harang|Area|Drops a barrier<br>blocking a lane for 3 s|25 s|Rising<br>barrier<br>sound|Can block the<br>Taya too|Stretch|
|TS_06|Amoy|Detection|Shows Runner<br>footprints for 5 s|18 s|Sniffing<br>sound|Footprints fade,<br>trail only|Stretch|



Page 8 of 16 

Habulan Rush: Game Design Document 

### 5.5 Ultimates 

Each player has one ultimate per role. It charges over time (100 seconds for full charge) and can be used once per round. 

|ID|Name|Role|Effect|Weakness|
|---|---|---|---|---|
|UL_01|Ligtas!|Runner|Call "safe": immune to tags for|Wastes time, Taya can wait|
||||2 s, cannot move||
|UL_02|Habol|Taya|Perfect lock on for 3 s, screen|Warns Runners, they can|
||Mode||flashes red for everyone|use escape skills|



Comeback charging: a Taya with the highest Taya Timer charges the Taya ultimate 25% faster. A Runner who has not been tagged for 60 s charges the Runner ultimate 25% faster. 

### 5.6 Skill Surge event 

Every 45 seconds of Round Live, all cooldowns reset and a loud sound plays. This creates a clear, exciting moment for spectators. 

### 5.7 Map pickups 

Skill orbs spawn at fixed spots (one every 20 seconds, max 3 on the map). Picking one gives a one time bonus: stamina refill, 1 s Safe Window, or 10% cooldown reduction. Maps may theme pickups (see section 9). 

## 6. Game modes 

|ID|Mode|Description|Tier|
|---|---|---|---|
|GM_01|Classic Habulan<br>(FFA)|Core mode: tag passing, lowest Taya time wins|MVP|
|GM_02|Time Trial (PvE)|Escape AI Taya through a course, leaderboard<br>for best time|MVP|
|GM_03|Team Habulan|Two teams, tagged players freeze until a<br>teammate touches them|Stretch|



Page 9 of 16 

Habulan Rush: Game Design Document 

|ID|Mode|Description|Tier|
|---|---|---|---|
|GM_04|Last Runner<br>Standing|Taya at the buzzer is out, last player left wins|Stretch|



Plain English: GM_01 is the main esports mode. GM_02 satisfies the competition's PvE leaderboard option so judges can try the game solo. 

## 7. Onboarding and tutorial 

Completeness criteria require instructions and a tutorial. 

1. **Tutorial map (60 to 90 s):** guided steps for move, sprint, dash, tag, use a skill, use an ultimate. 

2. **Prompts:** short on screen hints that fade after the first successful use. 

3. **Practice dummy:** a bot Taya in the tutorial that behaves predictably. 

4. **Skill cards:** each skill shows icon, name, cooldown, and one sentence in plain language. 

## 8. User interface 

|Element|Location|Content|
|---|---|---|
|Role banner|Top center|"TAYA" in red or "RUNNER" in green with icon (not<br>color alone, for accessibility)|
|Round timer|Top center|Countdown from 150 s|
|Scoreboard|Top right|Player names and live Taya Timer|
|Skill bar|Bottom center|Active skill, ultimate charge ring, cooldown<br>overlays|
|Stamina bar|Bottom left|Visible for Runners|
|Lock indicator|On target|Ring around locked Runner|
|Kill feed|Left|"Ana tagged Ben" style messages|



Accessibility: all critical states use both color and shape or icon. Offer a colorblind friendly palette option and a text size setting. 

Page 10 of 16 

Habulan Rush: Game Design Document 

## 9. Maps 

Each map changes how the game plays, not just how it looks. 

|ID|Map|Theme link|Gameplay effect|Tier|
|---|---|---|---|---|
|MP_01|Barangay<br>Kalsada|Philippine Games and<br>Sports|Open street, basketball<br>court, jeepney obstacles,<br>balanced layout.<br>Tournament map|MVP|
|MP_02|Binaha na<br>Baryo|Disaster Risk Reduction<br>and Management|Floodwater rises slowly and<br>shrinks the safe area.<br>Evacuation center zones<br>give a short Safe Window.<br>Loading screen shows flood<br>safety tips|MVP|
|MP_03|Palengke|Philippine culture|Tight stalls and alleys block<br>lock on, favors Runners|Stretch|
|MP_04|Palayan|Philippine culture|Mud patches slow everyone<br>by 20%, rewards jump skills|Stretch|
|MP_05|Recycling<br>Hub|Circular Economy|Collect recyclables for<br>pickups and bonus charge|Stretch|



Map requirements: 

- Size: about 150 by 150 studs for 6 players. 

- At least 8 spawn points spread evenly. 

- At least 3 vault obstacles and 2 low gaps for sliding. 

- No dead ends smaller than 10 studs (prevents corner trapping). 

- Neutral lighting and strong contrast so players stay readable. 

## 10. Art direction 

- Style: bright, stylized, friendly low poly with Filipino street details (sari-sari store, jeepney, flags, hand painted signs). 

- Characters: kid friendly avatars with custom outfits (tsinelas, school uniforms, basketball jerseys). 

Page 11 of 16 

Habulan Rush: Game Design Document 

- Role readability: Taya has a glowing red marker and a distinct outline visible through walls for spectators. 

- All art must be created by the team or licensed (competition rule B.6). 

- Visual effects: simple particle effects per skill, matching the tell column in section 5. 

## 11. Audio direction 

- Music: upbeat, rhythmic street music inspired by Filipino sounds, tempo rising in the last 30 seconds. 

- Sound effects: each skill has a unique sound that doubles as its tell. 

- Voice: short shouts in Filipino ("Taya ka!", "Safe!", "Habol!"). 

- All audio must be team made or licensed, and logged in `AI_LOG.md` if AI generated. 

## 12. Esports features 

|ID|Feature|Purpose|Tier|
|---|---|---|---|
|ES_01|Private lobbies with code|Tournament play|MVP|
|ES_02|Spectator camera (follow Taya, free cam, auto<br>switch)|Viewer friendly|MVP|
|ES_03|Clear scoreboard and timer|Easy to understand<br>rules|MVP|
|ES_04|Highlight moments (big escape, last second<br>tag)|Trailer and replays|Stretch|
|ES_05|Audience voting during the event|Game Feedback<br>criterion|Stretch|



#### Balance checklist before submission: 

1. No skill wins on its own in test matches. 

2. Taya win rate and Runner survival stay within a 40 to 60 percent band in internal tests. 

3. Every skill has been counter tested 1v1. 

Page 12 of 16 

Habulan Rush: Game Design Document 

## 13. Technical design (Roblox) 

### 13.1 Architecture 

|Module|Location|Responsibility|
|---|---|---|
|`Config`|ReplicatedStorage|All numbers (movement, skills, scoring)|
|`MatchService`|ServerScriptService|State machine MS_01 to MS_06, shuffle<br>bag, scoring|
|`TagService`|ServerScriptService|Pounce validation, tag passing, Safe<br>Window, Lock Delay|
|`SkillService`|ServerScriptService|Draft, cooldowns, effects, ultimates|
|`MovementController`|StarterPlayerScripts|Sprint, dash, slide, input, stamina UI|
|`TargetLockController`|StarterPlayerScripts|Soft lock camera and indicator|
|`UIController`|StarterPlayerScripts|HUD, skill bar, scoreboard|
|`Remotes`|ReplicatedStorage|RemoteEvents with validation (see 13.3)|



### 13.2 Rules for code 

- Server owns truth: state, cooldowns, hit results, scores. 

- Client owns input and presentation only. 

- Every skill is a table in `Config.Skills` with fields: `id` , `role` , `type` , `cooldown` , `duration` , `range` , `params` , `tell` , `weakness` . 

- Skills run through a shared `SkillService:Activate(player, skillId)` that checks: state is Round Live, cooldown ready, player has the skill, role matches. 

### 13.3 Remote events 

|Remote|Direction|Payload|Server check|
|---|---|---|---|
|`RequestPounce`|Client to<br>server|direction<br>vector|Role is Taya, cooldown ready, not<br>stunned|
|`RequestSkill`|Client to<br>server|skillId|See 13.2|



Page 13 of 16 

Habulan Rush: Game Design Document 

|Remote|Direction|Payload|Server check|
|---|---|---|---|
|`RequestDash`|Client to<br>server|direction<br>vector|Cooldown ready, stamina not required|
|`PickSkill`|Client to<br>server|slot, skillId|Only during MS_02, must be one of<br>the offered choices|
|`StateChanged`|Server to<br>clients|state, timer|None|
|`TagEvent`|Server to<br>clients|taggerId,<br>targetId|None|



Plain English: the player asks, the server decides, and everyone is told the result. 

### 13.4 Sample config shape 

```
Config.Skills = {
  RS_01 = { id = "RS_01", name = "Luksong Baka", role = "Runner", type =
"Escape",
            cooldown = 12, params = { height = 14, distance = 18 } },
  TS_01 = { id = "TS_01", name = "Sigaw", role = "Taya", type = "Detection",
            cooldown = 20, params = { radius = 40, revealTime = 2 } },
}
```

## 14. Schedule (submission deadline: October 25, 2026) 

Today is October 7. Aim to submit October 24 as a safety buffer. 

|Dates|Phase|Deliverables|
|---|---|---|
|Oct 7 to 8|Lock design|Approve this GDD, assign roles, set up shared repo<br>and Team Create|
|Oct 9 to 12|Core loop|MatchService, tag passing, Taya Timer, scoring,<br>basic HUD, Barangay Kalsada greybox|
|Oct 13 to 16|Skills|Skill Draft, 3 Runner and 3 Taya skills, 2 ultimates,<br>Skill Surge|
|Oct 17 to 19|Second map and PvE|Binaha na Baryo, Time Trial mode, tutorial|



Page 14 of 16 

Habulan Rush: Game Design Document 

|Dates|Phase|Deliverables|
|---|---|---|
|Oct 20 to 21|Polish and freeze|Art pass, audio, UI polish.**Feature freeze Oct 21**|
|Oct 22 to 23|Testing|Balance tests, bug fixing, 6 player playtests|
|Oct 23 to 24|Submission package|Trailer, demo video, synopsis, forms, upload|



If behind schedule, cut in this order: Time Trial polish, Binaha na Baryo hazards, ultimates, Skill Surge. Never cut the tutorial or the tag loop. 

## 15. Submission checklist 

|Item|Owner|Done|
|---|---|---|
|Registration through the official link|Team leader|No|
|Form 01: Game Development Team Roles|Team leader|No|
|Form 02: Waiver and Declaration of Originality<br>(signed by all members and coach)|All|No|
|Form 03: Asset and AI Usage Disclosure (required<br>if any AI or external assets are used)|All|No|
|Template 01: Synopsis, max 500 words|Writer|No|
|Game Trailer, 1 to 2 min .mp4|Video lead|No|
|Prototype/Demo, 3 to 5 min .mp4|Video lead|No|
|School head endorsement (student category)|Coach|No|
|Finalist extras: team name, school logo, ID photos,<br>proof of enrollment, poster|Team leader|No|



## 16. AI usage log 

Keep a file named `AI_LOG.md` in the repo from day one. Add one row each time AI is used. 

Page 15 of 16 

Habulan Rush: Game Design Document 

|Date|Tool|Area (code, art, audio,<br>writing, design)|What it<br>produced|Extent (minimal, moderate,<br>heavy)|Reviewed<br>by|
|---|---|---|---|---|---|



The organizers may request prompts, development logs, or version control records, so commit often with clear messages. 

## 17. Risks and open questions 

|ID|Item|Plan|
|---|---|---|
|OQ1|Is a Roblox experience eligible under the<br>publication rule?|Email or ask the DOST Regional Office<br>now, before building further|
|OQ2|Team size and roles (max 5 members)|Assign: lead and server scripter, client<br>scripter, builder and map artist, UI and<br>audio, video and documentation|
|OQ3|Who is the faculty coach for signing<br>forms?|Confirm this week|
|R1|18 days is tight|Strict MVP scope and feature freeze|
|R2|Random skills feel unfair|Draft choices, counter triangle, balance<br>tests|
|R3|Lag causes disputed tags|Server authority and 0.1 s rewind<br>window|
|R4|Free Toolbox assets cause<br>disqualification|Build or license everything, log the<br>source|
|R5|Tutorial skipped under time pressure|Treat tutorial as MVP, not stretch|



Page 16 of 16 


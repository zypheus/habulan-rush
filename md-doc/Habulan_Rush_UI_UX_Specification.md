# **HABULAN RUSH** 

## **UI / UX Specification** 

_Version 1.0 • Derived from GDD v2.0 §13–14 • PC, mobile and console via Roblox client_ 

### **1. UX principles** 

- Always know your role: Runner or Taya must be clear within a glance. 

- Minimal during action: show only what the current role needs. 

- Redundant coding: shape + icon + text + color; never color alone. 

- Spectator-friendly: key events visible without explanation. 

### **2. HUD layout** 

|**Element**|**Position**|**Content**|**Visible when**|
|---|---|---|---|
|Role banner|Top center|TAYA (red, hexagon icon) or RUNNER (blue,<br>circle icon)|Round Live|
|Round timer|Top center, under<br>banner|Countdown from 2:30; pulses at 0:10|Round Live|
|Scoreboard|Top right|Names + live Taya Time; own row highlighted|Round Live|
|Skill bar|Bottom center|Role skill icon, cooldown ring, Diskarte meter<br>and Move button|Round Live|
|Stamina bar|Bottom left|Runner-only; flashes when empty|Runner|
|Lock indicator|On target|Soft-lock ring|Taya with target|
|Event banner|Upper center|BARANGAY RUSH, HULING HABOL|On event|
|Clutch popup|Center|PERFECT ESCAPE, NICE READ, CLUTCH,<br>PERFECT POUNCE|On event|
|Tag feed|Left|"Player A tagged Player B", max 4 lines, 4 s<br>each|Round Live|
|Safe Window ring|Around player|Blue shield ring + countdown|During window|



### **3. Screen flows** 

|**Screen**|**Content**|**Interactions**|
|---|---|---|
|Lobby|Player list, ready, map vote, private code field, controls<br>help|Ready, vote, enter/copy code|
|Skill Draft|12 s timer; 2 Runner cards + 2 Taya cards|Tap/click one card per role; auto-<br>picks on timeout|
|Countdown|Large 5-4-3-2-1; first Taya shown|None|
|Round End|Rank, Taya Time, tags, escapes, counters, Diskarte<br>earned|Skippable after 3 s|
|Match End|Final ranking, Match MVP, identity label (e.g. "Escape<br>Specialist"), Best Diskarte recap|Return to lobby|
|Spectator|Follow Taya / free cam / auto-switch; scoreboard; event<br>banners|Cycle target, change camera|



Habulan Rush • UI / UX Specification • Page 1 

#### **3.1 Skill card** 

Fields in fixed order: icon, name, role, one-sentence effect, cooldown, tell, weakness. No technical wording. Example: "Lambat — Taya — Slows Runners in a net zone for 5 s. Cooldown 22 s. Tell: visible ground net. Weakness: can be jumped." 

### **4. Controls** 

|**Action**|**PC**|**Mobile**|**Console**|
|---|---|---|---|
|Move|WASD|Left thumbstick|Left stick|
|Camera|Mouse|Right drag|Right stick|
|Sprint|Left Shift (hold)|Sprint button|Left trigger|
|Dash|Q|Dash button|B|
|Slide|C|Slide button|Right bumper|
|Pounce (Taya)|Left click|Pounce button|Right trigger|
|Skill|E|Skill button|X|
|Diskarte Move|F|Diskarte button|Y|
|Lock target|Hold right click|Lock button|Left bumper|



Mobile buttons: minimum 64 px touch target, right-thumb cluster for dash/skill/pounce, repositionable in settings (P1). 

### **5. Feedback and juice** 

|**Event**|**Visual**|**Audio**|**Other**|
|---|---|---|---|
|Tag|Flash + role swap animation, Taya<br>banner changes|Slap + "Taya ka!"|Controller rumble, 0.1 s<br>camera punch|
|Safe Window|Blue ring + 2 s timer|Chime + "Safe!"|—|
|Skill ready|Icon glows|Soft tick|—|
|Diskarte full|Gold pulse around meter|Rising chime|Move button flashes|
|Huling Habol|Banner + vignette at 30 s, timer<br>pulses at 10 s|Music escalation|—|



### **6. Tutorial UX** 

- About 60 to 90 seconds for a first attempt, with no time limit: move and jump, dash to a gate, chain two accepted slides to earn sprint, tag a moving practice Runner prop, then read the win rule.

- One instruction at a time, shown as a short sentence. Server-observed success advances the step; a device-specific retry hint appears if the player pauses.

- First join offers Start and Later. Later dismisses the prompt; the lobby keeps a Learn to Play replay button. An idle solo player teleports to a reserved tutorial subplace, initially using Kalsada. A later tutorial map can keep the same waypoint names.

- The target is tutorial-only and never contributes match score. Completion is saved; failed saves can be retried or left unconfirmed. The final screen says Lowest cumulative Taya time wins and offers return to lobby. Skill, Diskarte, Panyo, and Secret Hunt lessons are deferred.

### **7. Accessibility** 

- Never rely on color: role and danger use shape, icon, outline and text. 

- Colorblind palette option (orange/blue) and high-contrast outline toggle. 

- Text size option (S/M/L) for critical UI; minimum 18 px on mobile at default. 

- Reduce screen shake and flashing toggle; no flashes above 3 per second. 

- Subtitle text for voice callouts (banner text already mirrors them). 

Habulan Rush • UI / UX Specification • Page 2 

### **8. UI acceptance criteria** 

- A new player identifies their role in under 2 s (QA test T-SPC-01). 

- A spectator names the Taya and the leader after 30 s without instruction. 

- All HUD elements remain readable on a 6-inch phone at 16:9. 

- Every critical state has at least two cues (e.g. icon + color + sound). 

Habulan Rush • UI / UX Specification • Page 3 


# **HABULAN RUSH** 

## **Art & Audio Bible** 

_Version 1.0 • Derived from GDD v2.0 §15–16 • Visual and sound rules for all team-made and licensed assets_ 

### **1. Creative pillars** 

- Playful, not realistic: bright, friendly low-poly with strong Filipino street details. 

- Readable first: role, danger and interactables must be understood in under a second, also by spectators. 

- Sound is information: every important event has a unique, recognizable audio tell. 

- Kid-friendly and respectful: local culture shown with warmth and accuracy. 

### **2. Art direction** 

#### **2.1 Palette** 

|**Use**|**Color**|**Hex**|**Rule**|
|---|---|---|---|
|Taya / danger|Signal red|#D62828|Role outline, Taya marker, pounce telegraph|
|Runner / safe|Cobalt blue|#1D6FE0|Runner marker, Safe Window ring|
|Diskarte|Gold|#F7B500|Meter, Diskarte Moves, clutch popups|
|Interactable|Teal|#14B8A6|Pickups, evacuation zones, event objects (always with an<br>icon)|
|UI text / dark|Deep navy|#1F3864|Panels and text on light backgrounds|
|Neutral light|Warm white|#FFF8EC|Panels and callout text|



Environment colors stay in mid-saturation and low contrast so that characters, role markers and effects always stand out. A colorblind-friendly option swaps red/blue for orange/blue with distinct shapes. 

#### **2.2 Environment** 

|**Map**|**Key assets**|**Readability rule**|
|---|---|---|
|Barangay Kalsada|Sari-sari stores, jeepney obstacles,<br>basketball court, hand-painted signs,<br>flags|Keep the center open; jeepneys are vault<br>height; court is visually distinct from streets|
|Binaha na Baryo|Raised houses, sandbags, boats,<br>evacuation signs, flood water|Water level markers on walls; evacuation<br>zones teal with icon|
|Recycling Hub (stretch)|Sorting bins, crates, conveyor props|Pickup spots are icons, not color only|
|Palengke / Palayan<br>(stretch)|Stalls, awnings; rice paddies, mud|Stall alleys wide enough to read chases; mud<br>has a distinct texture and icon|



#### **2.3 Characters** 

- Roblox avatars with local outfits: school uniforms, basketball jerseys, tsinelas, pambahay. 

- Role marker: Taya gets a red outline and a bold overhead icon visible through walls to spectators; Runner gets a small blue marker. 

- Silhouette test: roles and active skills must be identifiable in grayscale at 50% scale. 

Habulan Rush • Art & Audio Bible • Page 1 

#### **2.4 VFX** 

|**Effect**|**Look**|**Duration**|**Notes**|
|---|---|---|---|
|Dash|Short speed streak + dust|0.2 s|Same shape for all players|
|Pounce wind-up|Red ring contracting on Taya|0.35 s|Primary tell for Runners|
|Pounce lunge|Motion trail + impact burst on hit|0.31 s|Miss shows dust puff|
|Target lock|Ring around target, white|While locked|Breaks with a snap effect|
|Luksong Baka|Dust ring on takeoff|Instant|Readable arc|
|Pekeng Takbo|Smoke puff at spawn|Instant|Decoy is a slightly translucent<br>copy|
|Tsinelas Throw|Spinning slipper with arc|Flight time|Impact star on hit|
|Sigaw|Expanding shout ring|2 s reveal|Ring radius matches 40 studs|
|Lambat|Ground net grid|5 s|Edge outline = exact radius|
|Hatak|Speed lines + whoosh trail|1.5 s|—|
|Diskarte|Gold sparkle around meter; Move aura<br>per role|Move duration|Aura smaller than skill VFX|



Budget: at most 30 active emitters; prefer simple shapes and gradients over textures. 

### **3. Audio direction** 

#### **3.1 Music** 

|**State**|**Music**|**Notes**|
|---|---|---|
|Lobby / Draft|Light, upbeat Filipino street rhythm (kulintang-<br>inspired percussion + modern beat)|Low intensity so callouts are clear|
|SIMULA|Upbeat rhythmic loop, 120–128 BPM|Loops seamlessly|
|BARANGAY RUSH|Same loop plus a community layer (brass<br>band/claps) and an event sting|Layer fades in over 2 s|
|HULING HABOL|Stronger pattern, +10 BPM feel via added<br>percussion; heartbeat tick under 10 s|Adds layers at 50, 30, 15, 10 s|
|Round end|Hard stop, sting, then results theme|Silence of about 0.3 s before sting|



#### **3.2 SFX table** 

|**Event**|**Sound character**|**Priority**|
|---|---|---|
|Tag|Strong slap/clap confirmation + voice "Taya ka!"|Highest|
|Pounce wind-up|Rising whoosh with short inhale|High|
|Dash|Quick air burst|Medium|
|Safe Window start|Bright chime + "Safe!"|High|
|Skill tells|One unique sound per skill (hup, pop, whirr, shout, net rustle,<br>whoosh)|High|
|Diskarte full|Gold chime rising to a sparkle|High|
|Clutch callouts|Short sting per type|High|
|Footsteps/sprint|Surface-aware, low volume|Low|



#### **3.3 Voice lines** 

Short, clear and kid-friendly: "Taya ka!", "Safe!", "Habol!", "Huling habol!", "Huwag magpahuli!". Each line is under 1.2 s. Record or license voices from the team; do not imitate real people. 

Habulan Rush • Art & Audio Bible • Page 2 

#### **3.4 Mix rules** 

- Priority order when sounds overlap: tag > Safe > skill tells > callouts > music > ambience. 

- Music ducks 4–6 dB under voice and tags. 

- Provide a master, music and SFX volume slider. 

- Directional audio for skill tells within 60 studs. 

### **4. Asset sourcing and disclosure** 

- Only team-made or properly licensed assets; keep a source list (name, author, license, link, date). 

- Any AI-assisted asset is logged in AI_LOG.md with tool, date, extent and human review. 

- Avoid copyrighted music, brand logos and recognizable real people. Check licenses before Oct 24. 

### **5. Delivery checklist** 

|**Item**|**Priority**|**Done when**|
|---|---|---|
|Kalsada kit (stores, jeepneys, court, signs)|P0|Placed and readable in 6-player test|
|Role outline + marker|P0|Visible to spectators through walls|
|Skill VFX/SFX tells (6)|P0|Distinct in blind test|
|Music loops + Huling Habol layers|P0|Transitions have no pops|
|Voice lines (5)|P1|Recorded and mixed|
|Binaha na Baryo kit|P1|Flood and evac readable|
|Stretch map kits|P2|Only after freeze if stable|



Habulan Rush • Art & Audio Bible • Page 3 


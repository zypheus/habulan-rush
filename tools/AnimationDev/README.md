# Habulan Rush Animation Development

This folder is the repository source for original R15 movement animations. HRush_AnimDev.lua owns all animation data, validation, KeyframeSequence building, and local preview.

## Batch A and B status

- Batches A and B contain 11 newly authored original R15 animations.
- Batch B adds Dash, SlideEnter, SlideLoop, SlideExit, and SlideJump.
- All 11 published IDs supplied by the project owner are wired into `Config.Animations` and recorded in `ASSET_LOG.md`.
- The other 10 production animation entries remain placeholders with empty keyframe arrays.
- HRush_PipelineSelfTest is development-only. Never publish it or add it to Config.Animations.
- Legacy sprint, combined slide, and dash fallback IDs have been removed.
- Current runtime playback uses Sprint, Dash, and SlideLoop. The other published clips require approved movement-state integration before they become live tracks.

| Clip | Authoring summary |
|---|---|
| HRush_Walk | 0.70-second relaxed loop with a small forward lean, alternating contact, passing poses, arm overlap, and restrained torso counter-rotation |
| HRush_Sprint | 0.45-second athletic loop with 15 to 17 degree lean, strong opposite limbs, bent elbows, torso twist, head counter-rotation, two airborne beats, and FootstepL or FootstepR at contact |
| HRush_JumpStart | 0.20-second anticipation, deep compression, explosive extension, and asymmetric launch follow-through |
| HRush_Fall | 0.60-second air loop with spread limbs, slight forward lean, asymmetric drift, and a closed loop seam |
| HRush_Land | 0.25-second soft absorption and recovery with LandImpact at 0.08 seconds |
| HRush_LandHard | 0.40-second deep asymmetric crouch, one-hand plant, impact hold, and recovery with LandImpact at 0.10 seconds |
| HRush_Dash | 0.25-second sprint handoff, compression, stretched forward lean, swept arms, driving leg, and sprint-ready recovery |
| HRush_SlideEnter | 0.12-second sprint handoff, anticipation, fast body drop, and settle into the slide silhouette |
| HRush_SlideLoop | 0.45-second closed hold loop with a reclined torso, one extended leg, one tucked leg, wide braced arms, and subtle weight drift |
| HRush_SlideExit | 0.15-second brace, rise, leg exchange, and direct handoff into the opposite sprint contact pose |
| HRush_SlideJump | 0.30-second slide preload, launch, compact airborne tuck, and release toward the fall silhouette |

## Verified R15 hierarchy

The builder follows this body-part pose tree. The standard joint name is shown after the colon.

    HumanoidRootPart
      LowerTorso: Root
        UpperTorso: Waist
          Head: Neck
          LeftUpperArm: LeftShoulder
            LeftLowerArm: LeftElbow
              LeftHand: LeftWrist
          RightUpperArm: RightShoulder
            RightLowerArm: RightElbow
              RightHand: RightWrist
        LeftUpperLeg: LeftHip
          LeftLowerLeg: LeftKnee
            LeftFoot: LeftAnkle
        RightUpperLeg: RightHip
          RightLowerLeg: RightKnee
            RightFoot: RightAnkle

Roblox Pose names are body-part names. A generated R15 rig in the current Studio build confirmed all 15 joints. That generated rig uses AnimationConstraint instances, but the names and connected body parts match the standard R15 hierarchy.

References:

- <https://create.roblox.com/docs/reference/engine/classes/Pose>
- <https://create.roblox.com/docs/art/characters/export-avatar-animations-from-maya>
- <https://create.roblox.com/docs/reference/engine/classes/AnimationClipProvider>

## Data rules

Each animation is one AnimationSpecs entry containing name, looped, priority, duration, keyframes, and markers.

Each keyframe contains its time, easing style, easing direction, and a joint pose map. Missing joints use the identity transform.

Use Root for the transform applied to LowerTorso. It may use a small Y offset for bob, drop, or lean. The validator rejects X or Z root translation so animation data cannot create travel.

AnimDev.mirrorPose() mirrors left and right joints. AnimDev.mirrorCycleKeyframes() also shifts the copied keyframes by a phase offset for run cycles.

AnimDev.validate() checks:

- placeholders are not buildable;
- keyframe and marker times stay inside the duration;
- loop start and end poses match;
- joint names are valid;
- horizontal root translation is absent;
- adjacent rotations do not jump over 120 degrees unless either joint pose sets intentionalJump = true.

## Studio preview

1. Open the target place in Roblox Studio.
2. Create Workspace.AnimationDevelopment.
3. Insert a ModuleScript named HRush_AnimDev in that folder.
4. Paste the repository file tools/AnimationDev/HRush_AnimDev.lua into the ModuleScript.
5. Start a Play test so animation playback advances.
6. Open View, then Command Bar.
7. Run one of these commands:

    local A = require(workspace.AnimationDevelopment.HRush_AnimDev)
    A.validateAll()
    A.preview("HRush_SlideLoop", 1)

For quarter speed:

    local A = require(workspace.AnimationDevelopment.HRush_AnimDev)
    A.previewQuarterSpeed("HRush_SlideLoop")

For a scrubbed pose:

    local A = require(workspace.AnimationDevelopment.HRush_AnimDev)
    A.scrub("HRush_SlideLoop", 0.225)

preview() spawns a standard R15 rig, builds the KeyframeSequence, registers it through AnimationClipProvider:RegisterAnimationClip(), and plays it through the rig Animator. scrub() forces full preview weight before pausing so the requested pose remains visible.

## Batch B Studio review checklist

- [ ] `validateAll()` prints OK for Dash, SlideEnter, SlideLoop, SlideExit, and SlideJump.
- [ ] `buildAll(false)` creates all five Batch B KeyframeSequences.
- [ ] Preview every clip at normal speed, 0.25 speed, and representative scrub times.
- [ ] Check Dash from a Sprint contact pose through the stretched peak and back into Sprint without a neutral-pose pop.
- [ ] Check SlideEnter into SlideLoop, SlideLoop into SlideExit, and SlideLoop into SlideJump without a neutral-pose pop.
- [ ] Watch SlideLoop through several seams and confirm the hold does not twitch.
- [ ] Review from rear gameplay distance and both side angles. Confirm the extended and tucked legs remain distinguishable.
- [ ] Test the intended avatar proportions for ground clipping and arm or leg intersections.
- [ ] After IDs are wired, verify local and remote replication with two players and confirm the legacy combined slide does not also play.

## Build and publish a completed batch

Batches A and B are published and wired. Repeat this workflow for later approved batches.

1. Run require(workspace.AnimationDevelopment.HRush_AnimDev).validateAll() and fix every INVALID result in the batch.
2. Run require(workspace.AnimationDevelopment.HRush_AnimDev).buildAll(false).
3. In Explorer, expand Workspace.AnimationDevelopment.
4. For each completed KeyframeSequence, right-click it and select **Save to File**. Save the .rbxm with the exact HRush_ name.
5. Insert or select a standard R15 Block Rig.
6. Open Avatar, then Clip Editor, and select that rig.
7. Create and save one temporary blank clip if the rig does not yet contain an AnimSaves object.
8. Select the rig's AnimSaves object in Explorer, choose **Insert From File**, and select the .rbxm.
9. In the Animation Editor menu, choose **Load**, then select the imported sequence.
10. Confirm loop state, priority, duration, easing, and markers. For walk, sprint, jump, or fall replacement clips, confirm the final keyframe is named End.
11. Choose **Publish to Roblox**.
12. Set Creator to the same user or group that owns the Habulan Rush experience. Do not publish under a different owner.
13. Copy the real animation asset ID. Never invent an ID.
14. Send the ID to the project owner for insertion into Config.Animations.
15. After the ID is wired, remove that entry's temporary FallbackId, add the asset row to ASSET_LOG.md, and record the work in AI_LOG.md.

Official publishing references:

- <https://create.roblox.com/docs/animation/editor>
- <https://create.roblox.com/docs/education/build-it-play-it-island-of-move/sharing-animations>

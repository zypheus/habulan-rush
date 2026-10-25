# build-tutorial-zone.ps1
# Emits assets/TutorialTrainingZone.rbxmx, the model-only Tutorial training strip.
# Tooling only, not Luau. Owner: project-owner. Task: classic-tag-tutorial.

$ErrorActionPreference = 'Stop'
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$repoRoot = Split-Path -Parent $PSScriptRoot
$outPath = Join-Path $repoRoot 'assets\TutorialTrainingZone.rbxmx'

$COL = @{
  Navy  = 1190714
  Cream = 16775404
  Gold  = 16233728
  Red   = 14034984
  Blue  = 1929184
  Khaki = 10724005
  Row   = 16777164
  Trunk = 8150086
  Leaf  = 5932104
  Tire  = 1780277
}
$TXT = @{
  Cream = @(1.0, 0.97255, 0.92549)
  Gold  = @(0.96863, 0.7098, 0.0)
}
$MAT_PLASTIC = 256
$MAT_METAL = 1088
$MAT_NEON = 288

$SB = [System.Text.StringBuilder]::new()
$script:refN = 0

function A([string]$line) { [void]$script:SB.AppendLine($line) }

function Fn([double]$v) {
  $r = [Math]::Round($v, 10)
  $s = $r.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
  if ($s -eq '-0') { return '0' }
  return $s
}

function I([int]$n) { return ' ' * (2 * $n) }

function NR() {
  $script:refN++
  return ("HZ{0}" -f $script:refN)
}

$BASES = @{
  ident = @{ ax = @(1, 0, 0); ay = @(0, 1, 0); az = @(0, 0, 1) }
  faceN = @{ ax = @(1, 0, 0); ay = @(0, 1, 0); az = @(0, 0, 1) }
  faceS = @{ ax = @(-1, 0, 0); ay = @(0, 1, 0); az = @(0, 0, -1) }
  faceE = @{ ax = @(0, 0, -1); ay = @(0, 1, 0); az = @(1, 0, 0) }
  faceW = @{ ax = @(0, 0, 1); ay = @(0, 1, 0); az = @(-1, 0, 0) }
  flat  = @{ ax = @(0, 1, 0); ay = @(-1, 0, 0); az = @(0, 0, 1) }
}

function YawB([double]$deg) {
  $t = [Math]::PI * $deg / 180.0
  return @{ ax = @([Math]::Cos($t), 0, -[Math]::Sin($t)); ay = @(0, 1, 0); az = @([Math]::Sin($t), 0, [Math]::Cos($t)) }
}

function Part-Open {
  param(
    [string]$Name,
    [string]$Cls = 'Part',
    [double[]]$Sz,
    [double[]]$Pos,
    [hashtable]$B = $null,
    [string]$Ori = 'ident',
    [int]$Col,
    [int]$Mat = 256,
    [double]$T = 0,
    [bool]$Coll = $true,
    [bool]$Q = $true,
    [bool]$Tch = $true,
    [string]$Shape = '',
    [int]$Ind = 3
  )
  if ($null -eq $B) {
    $B = $BASES[$Ori]
    if ($null -eq $B) { throw ("unknown orientation preset {0}" -f $Ori) }
  }
  $ax = [double[]]$B['ax']
  $ay = [double[]]$B['ay']
  $az = [double[]]$B['az']
  $p = I $Ind
  A "$p<Item class=$dq$Cls$dq referent=$dq$(NR)$dq>"
  A "$p  <Properties>"
  A "$p    <string name=${dq}Name${dq}>$Name</string>"
  A "$p    <CoordinateFrame name=${dq}CFrame${dq}>"
  A "$p      <X>$(Fn $Pos[0])</X><Y>$(Fn $Pos[1])</Y><Z>$(Fn $Pos[2])</Z>"
  A "$p      <R00>$(Fn $ax[0])</R00><R01>$(Fn $ay[0])</R01><R02>$(Fn $az[0])</R02><R10>$(Fn $ax[1])</R10><R11>$(Fn $ay[1])</R11><R12>$(Fn $az[1])</R12><R20>$(Fn $ax[2])</R20><R21>$(Fn $ay[2])</R21><R22>$(Fn $az[2])</R22>"
  A "$p    </CoordinateFrame>"
  A "$p    <Vector3 name=${dq}size${dq}><X>$(Fn $Sz[0])</X><Y>$(Fn $Sz[1])</Y><Z>$(Fn $Sz[2])</Z></Vector3>"
  A "$p    <bool name=${dq}Anchored${dq}>true</bool>"
  A "$p    <bool name=${dq}CanCollide${dq}>$(if ($Coll) {'true'} else {'false'})</bool><bool name=${dq}CanQuery${dq}>$(if ($Q) {'true'} else {'false'})</bool><bool name=${dq}CanTouch${dq}>$(if ($Tch) {'true'} else {'false'})</bool>"
  if ($T -ne 0) { A "$p    <float name=${dq}Transparency${dq}>$(Fn $T)</float>" }
  A "$p    <token name=${dq}Material${dq}>$Mat</token>"
  A "$p    <Color3uint8 name=${dq}Color3uint8${dq}>$Col</Color3uint8>"
  if ($Shape -ne '') { A "$p    <token name=${dq}shape${dq}>$Shape</token>" }
  A "$p  </Properties>"
}

function Part-Close { param([int]$Ind = 3) A "$(I $Ind)</Item>" }

function Att {
  param([string]$AttName, [double[]]$AttPos, [int]$Ind = 4)
  $p = I $Ind
  A "$p<Item class=${dq}Attachment${dq} referent=$dq$(NR)$dq>"
  A "$p  <Properties>"
  A "$p    <string name=${dq}Name${dq}>$AttName</string>"
  A "$p    <CoordinateFrame name=${dq}CFrame${dq}>"
  A "$p      <X>$(Fn $AttPos[0])</X><Y>$(Fn $AttPos[1])</Y><Z>$(Fn $AttPos[2])</Z>"
  A "$p      <R00>1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12><R20>0</R20><R21>0</R21><R22>1</R22>"
  A "$p    </CoordinateFrame>"
  A "$p  </Properties>"
  A "$p</Item>"
}

function Model-Open { param([string]$MName, [string]$Tag = '', [int]$Ind = 2)
  $p = I $Ind
  A "$p<Item class=${dq}Model${dq} referent=$dq$(NR)$dq>"
  A "$p  <Properties>"
  A "$p    <string name=${dq}Name${dq}>$MName</string>"
  if ($Tag -ne '') {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Tag))
    A "$p    <BinaryString name=${dq}Tags${dq}>$b64</BinaryString>"
  }
  A "$p  </Properties>"
}

function Model-Close { param([int]$Ind = 2) A "$(I $Ind)</Item>" }

function SignBoard {
  param([string]$Name, [double[]]$Sz, [double[]]$Pos, [string]$Face, [string]$Text, [object[]]$TxtCol, [int]$Ind = 3)
  Part-Open $Name 'Part' $Sz $Pos -Ori $Face -Col $COL['Navy'] -Ind $Ind
  $gi = $Ind + 1
  A "$(I $gi)<Item class=${dq}SurfaceGui${dq} referent=$dq$(NR)$dq>"
  A "$(I ($gi + 1))<Properties>"
  A "$(I ($gi + 2))<string name=${dq}Name${dq}>BoardGui</string>"
  A "$(I ($gi + 2))<bool name=${dq}AlwaysOnTop${dq}>false</bool>"
  A "$(I ($gi + 2))<Vector2 name=${dq}CanvasSize${dq}><X>800</X><Y>600</Y></Vector2>"
  A "$(I ($gi + 2))<token name=${dq}Face${dq}>5</token>"
  A "$(I ($gi + 2))<float name=${dq}LightInfluence${dq}>0</float>"
  A "$(I ($gi + 2))<float name=${dq}PixelsPerStud${dq}>50</float>"
  A "$(I ($gi + 2))<token name=${dq}SizingMode${dq}>1</token>"
  A "$(I ($gi + 1))</Properties>"
  $li = $Ind + 2
  A "$(I $li)<Item class=${dq}TextLabel${dq} referent=$dq$(NR)$dq>"
  A "$(I ($li + 1))<Properties>"
  A "$(I ($li + 2))<string name=${dq}Name${dq}>Label</string>"
  A "$(I ($li + 2))<float name=${dq}BackgroundTransparency${dq}>1</float>"
  A "$(I ($li + 2))<Font name=${dq}FontFace${dq}><Family><url>rbxasset://fonts/families/GothamBold.json</url></Family><Weight>400</Weight><Style>Normal</Style></Font>"
  A "$(I ($li + 2))<UDim2 name=${dq}Position${dq}><XS>0</XS><XO>0</XO><YS>0</YS><YO>0</YO></UDim2>"
  A "$(I ($li + 2))<UDim2 name=${dq}Size${dq}><XS>1</XS><XO>0</XO><YS>1</YS><YO>0</YO></UDim2>"
  A "$(I ($li + 2))<string name=${dq}Text${dq}>$Text</string>"
  A "$(I ($li + 2))<Color3 name=${dq}TextColor3${dq}><R>$(Fn $TxtCol[0])</R><G>$(Fn $TxtCol[1])</G><B>$(Fn $TxtCol[2])</B></Color3>"
  A "$(I ($li + 2))<bool name=${dq}TextScaled${dq}>true</bool>"
  A "$(I ($li + 2))<bool name=${dq}TextWrapped${dq}>true</bool>"
  A "$(I ($li + 1))</Properties>"
  A "$(I $li)</Item>"
  A "$(I $gi)</Item>"
  Part-Close $Ind
}

function Sign {
  param([string]$Name, [string]$Text, [double[]]$Pos, [double]$W, [double]$H, [string]$Face, [object[]]$TxtCol, [int]$Ind = 3)
  $ph = $Pos[1] - $H / 2.0
  $off = $W / 2.0 - 0.7
  Part-Open "$($Name)PostA" 'Part' @(0.7, $ph, 0.7) @(($Pos[0] - $off), ($ph / 2), $Pos[2]) -Col $COL['Navy'] -Ind $Ind
  Part-Close $Ind
  Part-Open "$($Name)PostB" 'Part' @(0.7, $ph, 0.7) @(($Pos[0] + $off), ($ph / 2), $Pos[2]) -Col $COL['Navy'] -Ind $Ind
  Part-Close $Ind
  SignBoard $Name @($W, $H, 0.4) $Pos $Face $Text $TxtCol $Ind
}

function Arrow {
  param([string]$Name, [double[]]$Tip, [double]$Yaw, [int]$Col, [int]$Ind = 3)
  $base = YawB $Yaw
  $t = [Math]::PI * $Yaw / 180.0
  $sx = $Tip[0] - 1.9 * [Math]::Sin($t)
  $sz = $Tip[2] - 1.9 * [Math]::Cos($t)
  Part-Open "$($Name)Shaft" 'Part' @(1.4, 0.12, 2.2) @($sx, $Tip[1], $sz) -B $base -Col $Col -Coll $false -Q $false -Tch $false -Ind $Ind
  Part-Close $Ind
  foreach ($d in @(38, -38)) {
    $th = [Math]::PI * ($Yaw + $d) / 180.0
    $b = YawB ($Yaw + $d)
    $hx = $Tip[0] - 0.75 * [Math]::Sin($th)
    $hz = $Tip[2] - 0.75 * [Math]::Cos($th)
    Part-Open "$($Name)Head$([Math]::Abs($d))" 'Part' @(0.6, 0.12, 1.5) @($hx, $Tip[1], $hz) -B $b -Col $Col -Coll $false -Q $false -Tch $false -Ind $Ind
    Part-Close $Ind
  }
}

$dq = [char]34

A '<?xml version="1.0" encoding="utf-8"?>'
A '<roblox version="4">'
Model-Open 'TutorialTrainingZone' '' 1

Model-Open 'Base' '' 2
Part-Open 'FloorRow' 'Part' @(36, 0.9, 218) @(0, -0.45, 5099) -Col $COL['Row'] -Ind 3; Part-Close 3
Part-Open 'FloorTail' 'Part' @(14, 0.9, 92) @(0, -0.45, 4944) -Col $COL['Row'] -Ind 3; Part-Close 3
Part-Open 'FloorLoop' 'Part' @(45, 0.9, 10) @(-22.5, -0.45, 4893) -Col $COL['Row'] -Ind 3; Part-Close 3
Part-Open 'FloorLane' 'Part' @(14, 0.9, 310) @(-35, -0.45, 5053) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FloorConnector' 'Part' @(52, 0.9, 10) @(-19, -0.45, 5213) -Col $COL['Row'] -Ind 3; Part-Close 3
Part-Open 'FillerSouthEdge' 'Part' @(80, 0.9, 8) @(-15, -0.45, 4884) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerW2a' 'Part' @(10, 0.9, 2) @(-50, -0.45, 4889) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerW2b' 'Part' @(10, 0.9, 8) @(-50, -0.45, 4894) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerE2' 'Part' @(25, 0.9, 2) @(12.5, -0.45, 4889) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerE8' 'Part' @(25, 0.9, 8) @(12.5, -0.45, 4894) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerW92' 'Part' @(13, 0.9, 92) @(-48.5, -0.45, 4944) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerM92' 'Part' @(21, 0.9, 92) @(-17.5, -0.45, 4944) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerE92' 'Part' @(18, 0.9, 92) @(16, -0.45, 4944) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerW218' 'Part' @(13, 0.9, 218) @(-48.5, -0.45, 5099) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerM218' 'Part' @(10, 0.9, 218) @(-23, -0.45, 5099) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerE218' 'Part' @(7, 0.9, 218) @(21.5, -0.45, 5099) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerW10' 'Part' @(13, 0.9, 10) @(-50, -0.45, 5213) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerE10' 'Part' @(18, 0.9, 10) @(16, -0.45, 5213) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'FillerNorth27' 'Part' @(80, 0.9, 27) @(-15, -0.45, 5231.5) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'RollLandPad' 'Part' @(14, 0.12, 25) @(-35, 0.06, 5172.5) -Col $COL['Cream'] -Ind 3; Part-Close 3
Part-Open 'VaultRunPad' 'Part' @(14, 0.12, 15) @(-35, 0.06, 5067.5) -Col $COL['Cream'] -Ind 3; Part-Close 3
Part-Open 'ZipLandPad' 'Part' @(14, 0.12, 15) @(-35, 0.06, 4902.5) -Col $COL['Cream'] -Ind 3; Part-Close 3
Model-Close 2

Model-Open 'Walls' '' 2
Part-Open 'WallW' 'Part' @(0.9, 8, 365) @(-55, 4, 5062.5) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'WallE' 'Part' @(0.9, 8, 365) @(25, 4, 5062.5) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'WallN' 'Part' @(79.1, 8, 0.9) @(-15, 4, 5243.5) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'WallS' 'Part' @(79.1, 8, 0.9) @(-15, 4, 4880.5) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'CapW' 'Part' @(0.9, 0.6, 365) @(-55, 8.3, 5062.5) -Col $COL['Gold'] -Ind 3; Part-Close 3
Part-Open 'CapE' 'Part' @(0.9, 0.6, 365) @(25, 8.3, 5062.5) -Col $COL['Gold'] -Ind 3; Part-Close 3
Part-Open 'CapN' 'Part' @(79.1, 0.6, 0.9) @(-15, 8.3, 5243.5) -Col $COL['Gold'] -Ind 3; Part-Close 3
Part-Open 'CapS' 'Part' @(79.1, 0.6, 0.9) @(-15, 8.3, 4880.5) -Col $COL['Gold'] -Ind 3; Part-Close 3
Model-Close 2

Model-Open 'StartPlaza' '' 2
Part-Open 'ArchColW' 'Part' @(2, 9, 2) @(-7, 4.5, 5008) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'ArchColE' 'Part' @(2, 9, 2) @(7, 4.5, 5008) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'ArchBeam' 'Part' @(16, 1.5, 2) @(0, 9.75, 5008) -Col $COL['Gold'] -Ind 3; Part-Close 3
Part-Open 'WelcomePostW' 'Part' @(0.8, 8.85, 0.8) @(-6.1, 4.425, 4998.8) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'WelcomePostE' 'Part' @(0.8, 8.85, 0.8) @(6.1, 4.425, 4998.8) -Col $COL['Navy'] -Ind 3; Part-Close 3
SignBoard 'WelcomeBoard' @(14, 2.5, 0.4) @(0, 10.1, 4998.8) 'faceS' 'HABULAN RUSH TRAINING' $TXT['Gold'] 3
Part-Open 'PlazaPostEA' 'Part' @(0.7, 1.8, 0.7) @(15.2, 0.9, 5002) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'PlazaPostEB' 'Part' @(0.7, 1.8, 0.7) @(8.8, 0.9, 5002) -Col $COL['Navy'] -Ind 3; Part-Close 3
SignBoard 'PlazaBoardE' @(9, 2.4, 0.4) @(12, 3.0, 5002) 'faceW' 'TAYA TAGS. RUNNERS FLEE.' $TXT['Cream'] 3
Part-Open 'PlazaPostWA' 'Part' @(0.7, 1.8, 0.7) @(-15.2, 0.9, 5002) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'PlazaPostWB' 'Part' @(0.7, 1.8, 0.7) @(-8.8, 0.9, 5002) -Col $COL['Navy'] -Ind 3; Part-Close 3
SignBoard 'PlazaBoardW' @(9, 2.4, 0.4) @(-12, 3.0, 5002) 'faceE' 'LOWEST TAYA TIME WINS.' $TXT['Cream'] 3
Model-Close 2

Model-Open 'MoveLane' '' 2
Part-Open 'Hurdle' 'Part' @(8, 2, 1) @(0, 1, 5038) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'HurdleStripe' 'Part' @(8, 0.3, 1) @(0, 2.15, 5038) -Col $COL['Gold'] -Ind 3; Part-Close 3
Part-Open 'DiscMove' 'Part' @(0.44, 10, 10) @(0, 0.22, 5050) -Ori 'flat' -Shape '2' -Col $COL['Blue'] -Ind 3; Part-Close 3
Model-Close 2

Model-Open 'DashLane' '' 2
Part-Open 'GateColW' 'Part' @(1, 6, 1) @(-4.5, 3, 5062) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'GateColE' 'Part' @(1, 6, 1) @(4.5, 3, 5062) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'GateBeam' 'Part' @(10, 0.8, 1) @(0, 6.4, 5062) -Col $COL['Gold'] -Ind 3; Part-Close 3
Part-Open 'DiscDash' 'Part' @(0.44, 20, 20) @(0, 0.22, 5078) -Ori 'flat' -Shape '2' -Col $COL['Blue'] -Ind 3; Part-Close 3
Model-Close 2

Model-Open 'SprintLane' '' 2
Part-Open 'RailSlideW' 'Part' @(0.6, 1.2, 70) @(-9.3, 0.6, 5131) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'RailSlideE' 'Part' @(0.6, 1.2, 70) @(9.3, 0.6, 5131) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'DiscSlideStart' 'Part' @(0.44, 6, 6) @(0, 0.22, 5108) -Ori 'flat' -Shape '2' -Col $COL['Gold'] -Ind 3; Part-Close 3
Part-Open 'DiscSlideEnd' 'Part' @(0.44, 10, 10) @(0, 0.22, 5160) -Ori 'flat' -Shape '2' -Col $COL['Gold'] -Ind 3; Part-Close 3
Arrow 'ArrowSprintA' @(0, 0.06, 5118) 0 $COL['Navy'] 3
Arrow 'ArrowSprintB' @(0, 0.06, 5132) 0 $COL['Navy'] 3
Arrow 'ArrowSprintC' @(0, 0.06, 5146) 0 $COL['Navy'] 3
Model-Close 2

Model-Open 'TagCourt' '' 2
Part-Open 'CourtRailSE' 'Part' @(10, 1.2, 0.6) @(13, 0.6, 5172) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'CourtRailSW' 'Part' @(10, 1.2, 0.6) @(-13, 0.6, 5172) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'CourtRailNE' 'Part' @(12, 1.2, 0.6) @(12, 0.6, 5206) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'CourtRailNW' 'Part' @(12, 1.2, 0.6) @(-12, 0.6, 5206) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'CourtRailE' 'Part' @(0.6, 1.2, 34) @(18, 0.6, 5189) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'CourtRailW' 'Part' @(0.6, 1.2, 34) @(-18, 0.6, 5189) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'TagBand' 'Part' @(10, 0.15, 2) @(0, 0.075, 5186) -Col $COL['Red'] -Ind 3; Part-Close 3
Model-Close 2

Model-Open 'RollTower' '' 2
Part-Open 'RollPlat' 'Part' @(14, 2.2, 14) @(-35, 11.9, 5196) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'RollRailW' 'Part' @(0.6, 1.2, 14) @(-42, 13.6, 5196) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'RollRailE' 'Part' @(0.6, 1.2, 14) @(-28, 13.6, 5196) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'RollLadder' 'TrussPart' @(1, 13, 1) @(-35, 6.5, 5204.5) -Col $COL['Navy'] -Ind 3; Part-Close 3
Model-Close 2

Model-Open 'VaultLane' '' 2
Arrow 'ArrowChainA' @(-35, 0.06, 5140) 180 $COL['Gold'] 3
Arrow 'ArrowChainB' @(-35, 0.06, 5115) 180 $COL['Gold'] 3
Part-Open 'Crate' 'Part' @(12, 3.5, 5) @(-35, 1.75, 5080.5) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'CrateStripe' 'Part' @(12, 0.3, 0.3) @(-35, 3.65, 5082.85) -Col $COL['Gold'] -Ind 3; Part-Close 3
Model-Close 2

Model-Open 'SwingBar' 'SwingBar' 2
Part-Open 'SwingBarPostA' 'Part' @(1.5, 7.7, 1.5) @(-38.25, 3.85, 5028) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'SwingBarPostB' 'Part' @(1.5, 7.7, 1.5) @(-31.75, 3.85, 5028) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'GrabVolume' 'Part' @(9, 7, 9) @(-35, 5, 5028) -T 0.85 -Coll $false -Q $false -Col $COL['Cream'] -Ind 3; Part-Close 3
Part-Open 'Bar' 'Part' @(8, 1.4, 1.4) @(-35, 7, 5028) -Mat $MAT_METAL -Col $COL['Gold'] -Ind 3
Att 'Pivot' @(0, 0, 0) 4
Att 'ReleaseDirection' @(0, 0, -5) 4
Part-Close 3
Model-Close 2

$zipS = @(-35.0, 16.0, 4975.0)
$zipE = @(-35.0, 11.0, 4915.0)
$zd = @(($zipS[0] - $zipE[0]), ($zipS[1] - $zipE[1]), ($zipS[2] - $zipE[2]))
$zl = [Math]::Sqrt(($zd[0] * $zd[0] + $zd[1] * $zd[1] + $zd[2] * $zd[2]))
$z = @(($zd[0] / $zl), ($zd[1] / $zl), ($zd[2] / $zl))
$x = @($z[2], 0.0, -$z[0])
$xl = [Math]::Sqrt(($x[0] * $x[0] + $x[1] * $x[1] + $x[2] * $x[2]))
$x = @(($x[0] / $xl), ($x[1] / $xl), ($x[2] / $xl))
$y = @(($z[1] * $x[2] - $z[2] * $x[1]), ($z[2] * $x[0] - $z[0] * $x[2]), ($z[0] * $x[1] - $z[1] * $x[0]))
$zipBasis = @{ ax = $x; ay = $y; az = $z }

Model-Open 'Zipline' 'Zipline' 2
Part-Open 'ZipColStart' 'Part' @(3, 15, 3) @(-35, 7.5, 4975) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'ZipPlatStart' 'Part' @(10, 1, 10) @(-35, 15.5, 4975) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'ZipLadderStart' 'TrussPart' @(1, 16, 1) @(-35, 8, 4981.5) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'ZipColEnd' 'Part' @(3, 10, 3) @(-35, 5, 4915) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'ZipPlatEnd' 'Part' @(10, 1, 10) @(-35, 10.5, 4915) -Col $COL['Khaki'] -Ind 3; Part-Close 3
Part-Open 'ZipLadderEnd' 'TrussPart' @(1, 11, 1) @(-35, 5.5, 4908.5) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'GrabVolume' 'Part' @(9, 4, 9) @(-35, 18, 4975) -T 0.85 -Coll $false -Q $false -Col $COL['Cream'] -Ind 3; Part-Close 3
Part-Open 'ZipCable' 'Part' @(0.35, 0.35, 60.2) @(-35, 13.5, 4945) -B $zipBasis -Mat $MAT_METAL -Col $COL['Navy'] -T 0.2 -Coll $false -Q $false -Tch $false -Ind 3
Att 'Start' @(0, 0, 30.1) 4
Att 'End' @(0, 0, -30.1) 4
Part-Close 3
Model-Close 2

Model-Open 'Signs' '' 2
Sign 'SignMove' '1 MOVE + JUMP' @(10, 3.4, 5033) 10 3 'faceS' $TXT['Cream'] 3
Sign 'SignDash' '2 DASH THROUGH THE GATE' @(10, 3.4, 5061) 10 3 'faceS' $TXT['Cream'] 3
Sign 'SignSprint' '3 SLIDE x2 FOR SPRINT' @(10, 3.4, 5099) 10 3 'faceS' $TXT['Cream'] 3
Sign 'SignTag' '4 TAG THE RUNNER' @(10, 3.4, 5168) 10 3 'faceS' $TXT['Cream'] 3
Sign 'SignRoll' 'ROLLOFF: HARD LANDING ROLL' @(-38, 3.4, 5205) 8 3 'faceN' $TXT['Cream'] 3
Sign 'SignVault' 'VAULT: CHAIN 2 SLIDES FOR SPEED' @(-38, 3.4, 5100) 8 3 'faceN' $TXT['Cream'] 3
Sign 'SignSwing' 'SWING BAR' @(-38, 3.4, 5030) 8 3 'faceN' $TXT['Cream'] 3
Sign 'SignZip' 'ZIPLINE' @(-38, 3.4, 4968) 8 3 'faceN' $TXT['Cream'] 3
Model-Close 2

Model-Open 'Dressing' '' 2
Part-Open 'LampAPost' 'Part' @(2, 14, 2) @(-50, 7, 5170) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'LampAArm' 'Part' @(6, 0.8, 0.8) @(-50, 13.6, 5170) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'LampABulb' 'Part' @(1.6, 1.4, 1.6) @(-50, 12.4, 5170) -Mat $MAT_NEON -Col $COL['Gold'] -Ind 3; Part-Close 3
Part-Open 'LampBPost' 'Part' @(2, 14, 2) @(18, 7, 5235) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'LampBArm' 'Part' @(6, 0.8, 0.8) @(18, 13.6, 5235) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'LampBBulb' 'Part' @(1.6, 1.4, 1.6) @(18, 12.4, 5235) -Mat $MAT_NEON -Col $COL['Gold'] -Ind 3; Part-Close 3
Part-Open 'LampCPost' 'Part' @(2, 14, 2) @(-50, 7, 4925) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'LampCArm' 'Part' @(6, 0.8, 0.8) @(-50, 13.6, 4925) -Col $COL['Navy'] -Ind 3; Part-Close 3
Part-Open 'LampCBulb' 'Part' @(1.6, 1.4, 1.6) @(-50, 12.4, 4925) -Mat $MAT_NEON -Col $COL['Gold'] -Ind 3; Part-Close 3
Part-Open 'TreeATrunk' 'Part' @(3, 10, 3) @(19, 5, 5188) -Col $COL['Trunk'] -Ind 3; Part-Close 3
Part-Open 'TreeALeafA' 'Part' @(9, 5, 9) @(19, 11.5, 5188) -Col $COL['Leaf'] -Ind 3; Part-Close 3
Part-Open 'TreeALeafB' 'Part' @(7, 3, 7) @(19, 15, 5188) -Col $COL['Leaf'] -Ind 3; Part-Close 3
Part-Open 'TreeBTrunk' 'Part' @(3, 10, 3) @(-49, 5, 5120) -Col $COL['Trunk'] -Ind 3; Part-Close 3
Part-Open 'TreeBLeafA' 'Part' @(9, 5, 9) @(-49, 11.5, 5120) -Col $COL['Leaf'] -Ind 3; Part-Close 3
Part-Open 'TreeBLeafB' 'Part' @(7, 3, 7) @(-49, 15, 5120) -Col $COL['Leaf'] -Ind 3; Part-Close 3
Part-Open 'TreeCTrunk' 'Part' @(3, 10, 3) @(-49, 5, 5060) -Col $COL['Trunk'] -Ind 3; Part-Close 3
Part-Open 'TreeCLeafA' 'Part' @(9, 5, 9) @(-49, 11.5, 5060) -Col $COL['Leaf'] -Ind 3; Part-Close 3
Part-Open 'TreeCLeafB' 'Part' @(7, 3, 7) @(-49, 15, 5060) -Col $COL['Leaf'] -Ind 3; Part-Close 3
Part-Open 'TireA1' 'Part' @(0.7, 2.1, 2.1) @(22, 0.35, 5110) -Ori 'flat' -Shape '2' -Col $COL['Tire'] -Ind 3; Part-Close 3
Part-Open 'TireA2' 'Part' @(0.7, 2.1, 2.1) @(22, 1.05, 5110) -Ori 'flat' -Shape '2' -Col $COL['Tire'] -Ind 3; Part-Close 3
Part-Open 'TireA3' 'Part' @(0.7, 2.1, 2.1) @(22, 1.75, 5110) -Ori 'flat' -Shape '2' -Col $COL['Tire'] -Ind 3; Part-Close 3
Part-Open 'TireB1' 'Part' @(0.7, 2.1, 2.1) @(-52, 0.35, 5010) -Ori 'flat' -Shape '2' -Col $COL['Tire'] -Ind 3; Part-Close 3
Part-Open 'TireB2' 'Part' @(0.7, 2.1, 2.1) @(-52, 1.05, 5010) -Ori 'flat' -Shape '2' -Col $COL['Tire'] -Ind 3; Part-Close 3
Part-Open 'TireB3' 'Part' @(0.7, 2.1, 2.1) @(-52, 1.75, 5010) -Ori 'flat' -Shape '2' -Col $COL['Tire'] -Ind 3; Part-Close 3
Model-Close 2

Model-Close 1
A '</roblox>'

$outDir = Split-Path -Parent $outPath
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
[System.IO.File]::WriteAllText($outPath, $SB.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("wrote {0} with {1} referents" -f $outPath, $script:refN)

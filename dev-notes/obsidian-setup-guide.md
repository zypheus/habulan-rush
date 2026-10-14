---
title: obsidian setup guide for 1.14.4
type: seed
status: approved
owner: team
task: none
updated: 2026-10-14
source: https://obsidian.md/help/settings and https://obsidian.md/help/plugins/templates
related:
  - ./00-index.md
---

Click-path setup for Obsidian 1.14.4 on this vault. Do every step once.

## 1. Open the vault

Open Obsidian, choose Open folder as vault, and select the repo root (the folder holding AGENTS.md). The vault root is the repo root. Nothing is copied or moved.

## 2. Confirm the notes are visible

In the left sidebar, open Files. You should see `dev-notes/`, `md-doc/`, `AGENTS.md`, `AI_LOG.md`, `ASSET_LOG.md`, `DESIGN_LOCK.md`, and `MODULE_OWNERSHIP.md`. Folders starting with a dot (`.gemini`, `.agents`, `.obsidian`) never appear here. That is normal. Edit `.gemini/TASK.md` in the code editor.

## 3. Turn off wikilinks

1. Click the gear icon in the bottom-left corner. That opens Settings.
2. In the left list of the Settings window, click Files and links.
3. Under Links, find Use [[Wikilinks]] and turn the toggle OFF.
4. On the same page, set New link format to Relative path to file.
5. On the same page, leave Automatically update internal links ON.

This only changes links you create from now on. The notes already use Markdown links, so nothing existing changes. If you do not see Files and links, you are probably in a plugin's own settings page. Click Files and links in the left list of the Settings window to go back.

## 4. Point the Templates plugin at the template folder

1. In Settings, click Core plugins in the left list.
2. Find Templates in the list and make sure its toggle is ON. The toggle alone is not enough.
3. Click the small gear icon on the Templates row. That opens the plugin options.
4. Find Template folder location and type `dev-notes/templates`.
5. Close Settings.

If the gear icon does nothing, the plugin toggle is OFF. Turn it on first, then click the gear. If the folder is not suggested while typing, create it from the Files sidebar first (it already exists in this repo).

## 5. Insert a template with one hotkey

1. Create a new note where the filled note should live, for example under `dev-notes/playtests/`.
2. Press Ctrl+P (Windows) or Cmd+P (Mac). That opens the command palette.
3. Type `Templates: Insert template` and press Enter.
4. Pick the template. Its content lands at your cursor.

Optional hotkey: Settings, then Hotkeys in the left list, search `Templates`, click the plus next to `Templates: Insert template`, and press your shortcut.

## 6. Keep Restricted Mode on

Settings, then Community plugins in the left list. The toggle is called Restricted Mode. Leave it ON. This vault needs no community plugins.

## 7. Read frontmatter as text

Our notes use YAML frontmatter. If Obsidian shows it as a Properties panel instead of text, go to Settings, Editor, find Properties in document, and set it to Source. Then the raw keys are visible and editable.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| No Files and links page | Looking at a plugin page | Click Files and links in the Settings left list |
| Templates gear does nothing | Plugin toggle is off | Turn Templates ON first, then click its gear |
| Template folder not found | Typo in the path | Type exactly `dev-notes/templates` |
| Insert template missing from palette | Folder not set | Finish step 4 first, then retry |
| `.gemini/TASK.md` nowhere | Dot-folders are hidden | Normal. Open it in the code editor |
| Old notes still show `[[links]]` | Toggle only affects new links | Old links stay as written; ours are Markdown already |

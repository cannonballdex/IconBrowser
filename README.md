# Icon Browser — By Cannonballdex

Icon Browser is a small ImGui utility for MacroQuest that lists available icon glyph constants (from `mq.Icons`) so you can browse and copy icon glyphs and their constant names. It provides a searchable, numbered list and supports resizable columns (uses ImGui Table API when available and falls back to Columns).

## Features
- Displays every icon as: index number, glyph, and key/name.
- Live search/filter (case-insensitive) over both key and glyph text.
- Clear button to reset the filter.
- Stable alphabetical ordering of icon keys.
- Uses ImGui Table API when available so columns are user-resizable; otherwise falls back to Columns.
- Small initial widths for the first two columns (number, glyph) and a wider "Key / Name" column.

## Requirements
- MacroQuest with Lua and ImGui integration.
- `mq.Icons` available in the MQ Lua environment (the script reads icons from `require('mq.Icons')`).
- ImGui must have the relevant icon fonts merged (Font Awesome / Material, etc.) if you want glyphs to render correctly.

If `mq.Icons` is not available, the tool will run but show no icons. You can instead provide a local `lib.icons` mapping and modify the script to require that module.

## Installation
1. Place the script in your MacroQuest `lua/IconBrowser` folder, for example:
   - `lua/IconBrowser/init.lua`
2. In-game or in the MQ console, run:
   ```
   /lua run IconBrowser
   ```
   The ImGui window title is `Icon Browser by Cannonballdex`.

## Usage
- Type a substring in the Search box to filter icons (matches key or glyph).
- Click `Clear` to reset the search.
- Resize the window and (when supported) drag table column separators to adjust column widths.

## Configuration
- `SEARCH_MAX_WIDTH` (script constant) sets a cap on the search box width (pixels) if you want to limit the input width.
- To change the icon source, replace:
  ```lua
  local ICONS = require('mq.Icons')
  
## Troubleshooting
- ImGui paused / Missing End(): If a Lua error occurs inside an ImGui frame the overlay may pause. Resume with:
  ```
  /mqoverlay resume
  ```
  Fix the error in the script and rerun.
- Icons render as empty squares: your ImGui font does not include the icon glyphs. Ensure your MQ/ImGui startup merges the correct icon fonts (Font Awesome / Material) used by `mq.Icons`.
- No icons shown: confirm `mq.Icons` is present in your MQ environment.

## Extending
Suggested small enhancements you can add:
- Click a row to copy the icon key or glyph to the clipboard.
- Add a "favorites" list to bookmark frequently used icons.
- Export selected icon keys to a text file or chat.

## License & Attribution
- This viewer is provided "as-is" with no warranty. Use at your own risk.
- Icon glyph constants come from the `mq.Icons` mapping; font glyphs are from icon font projects (Font Awesome, Material Design, etc.) — respect their respective licenses when redistributing fonts or glyphs.
- Written and maintained by Cannonballdex.

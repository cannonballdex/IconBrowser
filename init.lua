-- Icon Browser - ImGui app for MacroQuest - By Cannonballdex
-- Shows icons from lib.icons or mq.Icons with numbering and a search box that resizes with the window.

---@type Mq
local mq = require('mq')
---@type ImGui
require 'ImGui'

-- Try local icon module first, fall back to MQ-provided icons
local ok_icons, ICONS = pcall(require, 'mq.Icons')
if not ok_icons or type(ICONS) ~= 'table' then
  ICONS = {}
  print('\ar[Icons] mq.Icons not available — icon browser will be empty.')
end


local openGUI = true

-- Filter text state
local IconFilter = ''

-- Maximum width for the search input (pixels). Adjust to make the box smaller/larger.
local SEARCH_MAX_WIDTH = 250

-- Helper: case-insensitive substring search
local function ci_find(haystack, needle)
  if not needle or needle == '' then return true end
  if not haystack then return false end
  return tostring(haystack):lower():find(tostring(needle):lower(), 1, true) ~= nil
end

-- HelpMarker helper
local function HelpMarker(desc)
  if not desc then return end
  if ImGui.IsItemHovered() then
    ImGui.BeginTooltip()
    ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
    ImGui.Text(desc)
    ImGui.PopTextWrapPos()
    ImGui.EndTooltip()
  end
end

-- Safe helpers for sizes (bindings vary)
local function safeGetContentRegionAvail()
  local ok, a, b = pcall(ImGui.GetContentRegionAvail)
  if not ok then return 400 end
  if type(a) == 'table' and a.x then return a.x end
  if type(a) == 'number' then return a end
  if type(b) == 'number' then return b end
  return 400
end

local function safeCalcTextWidth(text)
  local ok, res = pcall(ImGui.CalcTextSize, text)
  if not ok then return (#tostring(text) * 7) end -- fallback char estimate
  if type(res) == 'table' and res.x then return res.x end
  if type(res) == 'number' then return res end
  return (#tostring(text) * 7)
end

local function DrawMainWindow()
  -- Handle ImGui.Begin variants (some bindings return (open) others (open, visible))
  local a, b = ImGui.Begin('Icon Browser by Cannonballdex', openGUI)
  local window_open = a
  local window_visible = (b ~= nil) and b or a

  if not window_open then
    ImGui.End()
    openGUI = false
    return
  end

  if window_visible then
    -- Build a responsive search row where the InputText expands and the Clear button stays visible.
    local clear_label = 'Clear##iconfilter_clear'
    local input_label = 'Search##iconfilter'

    -- Compute button width (text width + padding) and item spacing
    local btn_text = 'Clear'
    local btn_text_w = safeCalcTextWidth(btn_text)
    local btn_padding = 18 -- internal padding estimate
    local btn_w = math.max(48, btn_text_w + btn_padding)

    local spacing_x = 8
    local avail = safeGetContentRegionAvail()
    -- Reserve space for the Clear button + spacing; compute available width for input
    local computed_input_w = math.max(80, avail - (btn_w + spacing_x + 8))
    -- Cap the input width so the box stays smaller
    local input_w = math.min(computed_input_w, SEARCH_MAX_WIDTH)

    ImGui.SetNextItemWidth(input_w)
    IconFilter, _ = ImGui.InputText(input_label, IconFilter or '')

    ImGui.SameLine()
    if ImGui.SmallButton(clear_label) then IconFilter = '' end
    HelpMarker('Filter icons by key or glyph text (case-insensitive). Click Clear to reset.')

    -- Collect and sort icon keys for stable listing
    local keys = {}
    for k in pairs(ICONS) do table.insert(keys, k) end
    table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)

    -- Start scrollable area
    ImGui.BeginChild('IconsList', 0, -ImGui.GetFrameHeightWithSpacing(), true)

    local filter = IconFilter or ''
    local index = 0

    -- Prefer ImGui Table API (resizable columns) when available
    if ImGui.BeginTable then
      local flags = ImGuiTableFlags_Resizable or 0
      local ok_table, opened = pcall(ImGui.BeginTable, 'IconsTable', 3, flags)
      if ok_table and opened then
        -- Setup columns with initial smaller widths for first two columns
        pcall(ImGui.TableSetupColumn, 'No.', 0, 48)    -- initial width 48px
        pcall(ImGui.TableSetupColumn, 'Glyph', 0, 36) -- initial width 36px
        pcall(ImGui.TableSetupColumn, 'Key / Name', 0, 200)
        pcall(ImGui.TableHeadersRow)

        for _, key in ipairs(keys) do
          local glyph = ICONS[key]
          if ci_find(key, filter) or ci_find(glyph, filter) then
            index = index + 1
            pcall(ImGui.TableNextRow)
            pcall(ImGui.TableSetColumnIndex, 0); pcall(ImGui.Text, string.format('%03d', index))
            pcall(ImGui.TableSetColumnIndex, 1); pcall(ImGui.Text, tostring(glyph or ''))
            pcall(ImGui.TableSetColumnIndex, 2); pcall(ImGui.TextColored, 0.9, 0.9, 0.9, 1, tostring(key))
          end
        end

        if index == 0 then
          pcall(ImGui.TableNextRow)
          pcall(ImGui.TableSetColumnIndex, 0); pcall(ImGui.Text, '')
          pcall(ImGui.TableSetColumnIndex, 1); pcall(ImGui.Text, '')
          pcall(ImGui.TableSetColumnIndex, 2); pcall(ImGui.TextColored, 1, 0.8, 0.2, 1, 'No icons match the filter.')
        end

        pcall(ImGui.EndTable)
      else
        -- Fallback to Columns if BeginTable isn't usable
        ImGui.Columns(3, 'icon_cols', false)
        ImGui.Text('No.'); ImGui.NextColumn()
        ImGui.Text('Glyph'); ImGui.NextColumn()
        ImGui.Text('Key / Name'); ImGui.NextColumn()
        ImGui.Separator()

        -- Try to set small widths for first two columns (pcall in case binding differs)
        pcall(function()
          ImGui.SetColumnWidth(0, 48)
          ImGui.SetColumnWidth(1, 36)
        end)

        for _, key in ipairs(keys) do
          local glyph = ICONS[key]
          if ci_find(key, filter) or ci_find(glyph, filter) then
            index = index + 1
            ImGui.Text(string.format('%03d', index)); ImGui.NextColumn()
            ImGui.Text(tostring(glyph or '')); ImGui.NextColumn()
            ImGui.TextColored(0.9, 0.9, 0.9, 1, tostring(key)); ImGui.NextColumn()
          end
        end

        if index == 0 then
          ImGui.Separator()
          ImGui.TextColored(1, 0.8, 0.2, 1, 'No icons match the filter.')
        end

        ImGui.Columns(1)
      end
    else
      -- Table API not present: use Columns fallback
      ImGui.Columns(3, 'icon_cols', false)
      ImGui.Text('No.'); ImGui.NextColumn()
      ImGui.Text('Glyph'); ImGui.NextColumn()
      ImGui.Text('Key / Name'); ImGui.NextColumn()
      ImGui.Separator()

      pcall(function()
        ImGui.SetColumnWidth(0, 48)
        ImGui.SetColumnWidth(1, 36)
      end)

      for _, key in ipairs(keys) do
        local glyph = ICONS[key]
        if ci_find(key, filter) or ci_find(glyph, filter) then
          index = index + 1
          ImGui.Text(string.format('%03d', index)); ImGui.NextColumn()
          ImGui.Text(tostring(glyph or '')); ImGui.NextColumn()
          ImGui.TextColored(0.9, 0.9, 0.9, 1, tostring(key)); ImGui.NextColumn()
        end
      end

      if index == 0 then
        ImGui.Separator()
        ImGui.TextColored(1, 0.8, 0.2, 1, 'No icons match the filter.')
      end

      ImGui.Columns(1)
    end

    ImGui.EndChild()
  end

  ImGui.End()
end

-- Initialize ImGui window and main loop
mq.imgui.init('Icon Browser', DrawMainWindow)

-- Keep the script alive while the window is open
while openGUI do
  mq.delay(100)
end
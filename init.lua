-- cauldron.lua scribbled by Cannonballdex (refined)
-- Add and Remove Items from the config file
-- Shows time left on cauldron cooldown
-- Add items by name using the input text boxes
-- Add items directly from cursor with "Add Cursor to Keep/Destroy" buttons

local mq = require('mq')
local ImGui = require('ImGui')

local Open = true
local ShowUI = true
local pause_switch = true

local LOOT_FILE = ''
local LOOT_CONFIG_CHECK = ''

-- Track last item event to display in GUI
local lastAction = { kind = nil, name = nil, time = 0 }
local function setLastAction(kind, name)
    lastAction.kind = kind
    lastAction.name = name
    lastAction.time = os.time()
end
local function formatAgo(t)
    if not t or t == 0 then return "" end
    local secs = os.time() - t
    if secs < 60 then
        return string.format("%ds ago", secs)
    else
        return string.format("%dm%ds ago", math.floor(secs/60), secs%60)
    end
end

-- Ensure config lists exist (defined early so we can call it right after loading)
local function ensureLists()
    LOOT_CONFIG.items_to_keep = LOOT_CONFIG.items_to_keep or {}
    LOOT_CONFIG.items_to_destroy = LOOT_CONFIG.items_to_destroy or {}
end

local function loot_file_exists(path)
    local file = io.open(path, "r")
    if file ~= nil then
        io.close(file)
        return true
    end
    return false
end

CONFIG_DIR = mq.TLO.MacroQuest.Path() .. "\\lua\\Cauldron\\"
LOOT_FILE = 'config.lua'
LOOT_CONFIG_CHECK = CONFIG_DIR .. LOOT_FILE

-- Ensure require can load from Cauldron directory
package.path = CONFIG_DIR .. "?.lua;" .. package.path

if loot_file_exists(LOOT_CONFIG_CHECK) then
    LOOT_CONFIG = require('config')
else
    LOOT_CONFIG = require('config_default')
end

-- Make sure tables exist immediately after loading config
ensureLists()

-- UI state for typed inputs and feedback
local ui = { keepInput = "", destroyInput = "" }

-- Helpers for list ops and saving the config
local function listContains(list, name)
    for _, v in ipairs(list or {}) do
        if v == name then return true end
    end
    return false
end

local function removeFromList(list, name)
    for i = #list, 1, -1 do
        if list[i] == name then
            table.remove(list, i)
            return true
        end
    end
    return false
end

local function saveConfigToFile()
    ensureLists()

    local function q(s)
        s = tostring(s or "")
        s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
        return '"' .. s .. '"'
    end

    local function serialize(list)
        local out = {}
        for _, v in ipairs(list) do
            table.insert(out, "        " .. q(v) .. ",")
        end
        return table.concat(out, "\n")
    end

    local content = table.concat({
        "return {",
        "    items_to_destroy = {",
        serialize(LOOT_CONFIG.items_to_destroy),
        "    },",
        "",
        "    items_to_keep = {",
        serialize(LOOT_CONFIG.items_to_keep),
        "    },",
        "}",
        ""
    }, "\n")

    local f, err = io.open(LOOT_CONFIG_CHECK, "w")
    if not f then
        print(("Config save failed: %s"):format(tostring(err)))
        return false
    end
    f:write(content)
    f:close()
    print(("Config saved: %s"):format(LOOT_CONFIG_CHECK))
    return true
end

local function addKeep(name, persist)
    ensureLists()
    removeFromList(LOOT_CONFIG.items_to_destroy, name)
    if not listContains(LOOT_CONFIG.items_to_keep, name) then
        table.insert(LOOT_CONFIG.items_to_keep, name)
        print(("Added '%s' to Keep."):format(name))
    else
        print(("'%s' already in Keep."):format(name))
    end
    if persist then saveConfigToFile() end
end

local function addDestroy(name, persist)
    ensureLists()
    removeFromList(LOOT_CONFIG.items_to_keep, name)
    if not listContains(LOOT_CONFIG.items_to_destroy, name) then
        table.insert(LOOT_CONFIG.items_to_destroy, name)
        print(("Added '%s' to Destroy."):format(name))
    else
        print(("'%s' already in Destroy."):format(name))
    end
    if persist then saveConfigToFile() end
end

local function removeKeep(name, persist)
    ensureLists()
    if removeFromList(LOOT_CONFIG.items_to_keep, name) then
        print(("Removed '%s' from Keep."):format(name))
        if persist then saveConfigToFile() end
    else
        print(("'%s' not found in Keep."):format(name))
    end
end

local function removeDestroy(name, persist)
    ensureLists()
    if removeFromList(LOOT_CONFIG.items_to_destroy, name) then
        print(("Removed '%s' from Destroy."):format(name))
        if persist then saveConfigToFile() end
    else
        print(("'%s' not found in Destroy."):format(name))
    end
end

-- Robust InputText reader (supports either (changed, value) or just (value))
local function readInputText(id, buf)
    local a, b = ImGui.InputText(id, buf or "")
    if type(a) == "boolean" and type(b) == "string" then
        return b
    elseif type(a) == "string" then
        return a
    end
    return buf or ""
end

local function Stop()
    print('\ayYou are out of room for items, ending script')
    mq.exit()
end
local function Stop2()
    print('\ayOut of empty inventory slots, ending script')
    mq.exit()
end
local function LoreItem()
    print('\ayTried to summon a Lore item')
end
local function FailedSummon()
    print('\aySummon failed, try again later')
end
local function Bulwark()
    print('\ayBulwark of Many Portals summoned')
end

mq.event('NoSlot', "#*#There was no place to put that!#*#", Stop)
mq.event('NoRoom', "#*#There are no open slots for the held item in your inventory.#*#", Stop2)
mq.event('LoreItem', "#*#Duplicate Lore items are not allowed.#*#", LoreItem)
mq.event('FailedSummon', "#*#Your summoning implodes in a sulfurous cloud.#*#", FailedSummon)
mq.event('Bulwark', "#*#A strange door appears in your hands.#*#", Bulwark)

-- Spells to Try From Best to Worst
local SPELLS_TO_TRY = {
    --"Summon Cauldron of Endless Abundance Rk. III",
    "Summon Cauldron of Endless Abundance Rk. II",
    "Summon Cauldron of Endless Abundance",
    "Summon Cauldron of Endless Bounty Rk. III",
    "Summon Cauldron of Endless Bounty Rk. II",
    "Summon Cauldron of Endless Bounty",
    "Summon Cauldron of Endless Goods",
    "Summon Cauldron of Many Things",
}

local function CheckSpell()
    if mq.TLO.Me.Class.ShortName() ~= 'MAG' then
        print('\arScript only runs on Magicians with a spell to summon a cauldron.')
        mq.cmd('/lua stop cauldron')
        return
    end

    if mq.TLO.Me.Moving() or mq.TLO.Me.Invis() or mq.TLO.Me.Hovering() or mq.TLO.Me.Combat() then
        return
    end

    if  mq.TLO.FindItemCount(109884)() == 0 and
        mq.TLO.FindItemCount(109883)() == 0 and
        mq.TLO.FindItemCount(109882)() == 0 and
        mq.TLO.FindItemCount(85480)()  == 0 and
        mq.TLO.FindItemCount(85481)()  == 0 and
        mq.TLO.FindItemCount(85482)()  == 0 and
        mq.TLO.FindItemCount(52880)()  == 0 and
        mq.TLO.FindItemCount(52795)()  == 0
    then
        if mq.TLO.Plugin('mq2mage')() then
            mq.cmd('/docommand /mag pause on')
        end

        for _, spell in ipairs(SPELLS_TO_TRY) do
            if mq.TLO.Me.Book(spell)() then
                -- Stop any current casting
                if mq.TLO.Me.Casting() then
                    mq.cmd('/stopcast')
                    mq.delay(300)
                end

                -- Memorize into gem 1 with quotes
                mq.cmdf('/memspell 1 "%s"', spell)

                -- Wait until gem 1 is actually the requested spell (up to ~5s)
                mq.delay(100)
                mq.delay(5000, function()
                    local g1 = mq.TLO.Me.Gem(1)
                    return g1() ~= nil and g1.Name() == spell
                end)

                -- If still not memorized, fall back to /mem
                if not (mq.TLO.Me.Gem(1)() and mq.TLO.Me.Gem(1).Name() == spell) then
                    mq.cmdf('/mem 1 "%s"', spell)
                    mq.delay(100)
                    mq.delay(5000, function()
                        local g1 = mq.TLO.Me.Gem(1)
                        return g1() ~= nil and g1.Name() == spell
                    end)
                end

                -- Only cast if gem 1 matches
                if mq.TLO.Me.Gem(1)() and mq.TLO.Me.Gem(1).Name() == spell then
                    mq.cmd('/cast 1')
                    mq.delay('10s')
                    mq.cmd('/autoinventory')                    
                else
                    print(string.format('Warning: failed to memorize "%s" to gem 1', spell))
                end

                break
            end
        end

        if mq.TLO.Plugin('mq2mage')() then
            mq.cmd('/docommand /mag pause off')
            mq.delay(1000)
        end
    end
end

-- Cauldrons to Try From Best to Worst
local CAULDRONS_TO_TRY = {
    "Cauldron of Endless Abundance III",
    "Cauldron of Endless Abundance II",
    "Cauldron of Endless Abundance",
    "Cauldron of Countless Goods III",
    "Cauldron of Countless Goods II",
    "Cauldron of Countless Goods",
    "Cauldron of Endless Goods",
    "Cauldron of Many Things",
}

local function CheckCauldron()
    for _, name in ipairs(CAULDRONS_TO_TRY) do
        local item = mq.TLO.FindItem('=' .. name)
        if item() ~= nil
            and not mq.TLO.Me.Moving()
            and tonumber(item.TimerReady()) == 0
            and mq.TLO.Me.FreeInventory() >= 1
            and not mq.TLO.Me.Combat()
            and not mq.TLO.Me.Hovering()
            and not mq.TLO.Me.Invis()
        then
            mq.cmdf('/useitem "%s"', name)
            mq.delay('10s')
            break
        end
    end
end

local function KeepItem()
    ::CheckCursor::
    for _, itemNameDestroy in pairs(LOOT_CONFIG.items_to_destroy) do
        if mq.TLO.Cursor.ID() ~= nil and mq.TLO.Cursor.Name() == itemNameDestroy then
            print('\ar[\aoCauldron.lua\ar] Destroyed:\aw', mq.TLO.Cursor.Name())
            mq.cmd('/destroy')
            mq.delay(500)
            setLastAction('destroy', itemNameDestroy)
            goto CheckCursor
        end
    end
    for _, itemNameKeep in pairs(LOOT_CONFIG.items_to_keep) do
        if mq.TLO.Cursor.ID() ~= nil and mq.TLO.Cursor.Name() == itemNameKeep then
            print('\ar[\aoCauldron.lua\ar]\ag Keeping:\aw', mq.TLO.Cursor.Name())
            mq.cmd('/autoinventory')
            mq.delay(500)
            setLastAction('keep', itemNameKeep)
            goto CheckCursor
        end
    end
    if mq.TLO.Cursor.ID() ~= nil then
        print('\ar[\aoCauldron.lua\ar]\ag Clear Cursor:\aw', mq.TLO.Cursor.Name())
        print('\ar[\aoCauldron.lua\ar]\atIf you are trying to move items around, please pause the script.')
        mq.cmd('/autoinventory')
        mq.delay(500)
        goto CheckCursor
    end
end

local function DestroyInventory()
    local function clearCursor()
        if mq.TLO.Cursor.ID() ~= nil then
            mq.cmd('/autoinventory')
            mq.delay(80)
        end
    end

    for _, itemName in pairs(LOOT_CONFIG.items_to_destroy) do
        clearCursor()

        for pack = 1, 10 do
            local packItem = mq.TLO.InvSlot(string.format('pack%d', pack)).Item
            if packItem() ~= nil then
                local capacity = tonumber(packItem.Container()) or 0

                if capacity > 0 then
                    -- Bag: iterate inner slots high -> low to avoid index shifts
                    for j = capacity, 1, -1 do
                        local inner = packItem.Item(j)
                        if inner() ~= nil and inner.Name() == itemName then
                            clearCursor()
                            -- Click inner bag slot using the "in packX Y" syntax
                            mq.cmdf('/shift /itemnotify in pack%d %d leftmouseup', pack, j)
                            mq.delay(120)

                            if mq.TLO.Cursor.ID() ~= nil and mq.TLO.Cursor.Name() == itemName then
                                print('\ar[\aoCauldron.lua\ar] Destroyed:\aw', itemName)
                                mq.cmd('/destroy')
                                mq.delay(150)
                                setLastAction('destroy', itemName)
                                clearCursor()
                            else
                                print(string.format('Warning: Could not shift-pick %s from in pack%d %d', itemName, pack, j))
                            end
                        end
                    end
                else
                    -- Non-bag item directly in this pack slot
                    if packItem.Name() == itemName then
                        clearCursor()
                        mq.cmdf('/shift /itemnotify pack%d leftmouseup', pack)
                        mq.delay(120)
                        if mq.TLO.Cursor.ID() ~= nil and mq.TLO.Cursor.Name() == itemName then
                            print('\ar[\aoCauldron.lua\ar] Destroyed:\aw', itemName)
                            mq.cmd('/destroy')
                            mq.delay(150)
                            setLastAction('destroy', itemName)
                            clearCursor()
                        else
                            print(string.format('Warning: Could not shift-pick %s from pack%d', itemName, pack))
                        end
                    end
                end
            end
        end
    end
end

-- Helper: format seconds as mm:ss
local function formatSeconds(s)
    local n = math.floor(tonumber(s or 0))
    local m = math.floor(n / 60)
    local sec = n % 60
    return string.format('%02d:%02d', m, sec)
end

-- Helper: pick best cauldron in inventory and return cooldown remaining (exact match)
local function getCauldronCooldown()
    for _, name in ipairs(CAULDRONS_TO_TRY) do
        local item = mq.TLO.FindItem('=' .. name)
        if item() ~= nil then
            local readyIn = tonumber(item.TimerReady()) or 0
            return name, readyIn
        end
    end
    return nil, nil
end

-- Gate heavy work, but always process cursor items for announcements
local function shouldRunCursorChecks()
    -- If there's anything on the cursor, process immediately (enables keep announcements)
    if mq.TLO.Cursor.ID() ~= nil then
        return true
    end

    local _, cd = getCauldronCooldown()
    if cd == nil then
        -- No cauldron found: still allow inventory cleanup
        return true
    end

    -- If within ~60s of ready, or very far (freshly used), allow normal cycle.
    return cd < 60 or cd > 1740
end

local function CauldronGUI()
    if Open then
        Open, ShowUI = ImGui.Begin('Cauldron by Cannonballdex', Open)
        ImGui.SetWindowSize(500, 500, ImGuiCond.Once)
        if ShowUI then
            if pause_switch then
                if ImGui.Button('Run') then
                    pause_switch = false
                end
                ImGui.SameLine()
                if ImGui.Button('End') then
                    mq.cmd('/lua stop cauldron')
                end
                ImGui.SameLine()
                ImGui.TextColored(1.0, 1.0, 0.0, 1.0, " Script Status: [ PAUSED ] ")
            else
                if ImGui.Button('Pause') then
                    pause_switch = true
                end
                ImGui.SameLine()
                if ImGui.Button('End') then
                    mq.cmd('/lua stop cauldron')
                end
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, " Script Status: [ RUNNING ] ")
                ImGui.Separator()
                local name, cd = getCauldronCooldown()
                if name then
                    if cd > 0 then
                        ImGui.TextColored(1, 0.85, 0, 1, string.format("Cauldron: %s | Cooldown: %s", name, formatSeconds(cd)))
                    else
                        ImGui.TextColored(0, 1, 0, 1, string.format("Cauldron: %s | Ready", name))
                    end
                else
                    ImGui.TextColored(1, 0.5, 0.5, 1, "Cauldron: None found in inventory")
                end
            end

            -- Last action banner (Kept/Saved or Destroyed)
            ImGui.Separator()
            local lastKind = lastAction.kind
            local lastName = lastAction.name or "-"
            local agoText = formatAgo(lastAction.time)
            if lastKind == 'keep' then
                ImGui.TextColored(0, 1, 0, 1, string.format("Last action: Saved (Kept) '%s' %s", lastName, agoText))
            elseif lastKind == 'destroy' then
                ImGui.TextColored(1, 0.3, 0.3, 1, string.format("Last action: Destroyed '%s' %s", lastName, agoText))
            else
                ImGui.TextColored(0.8, 0.8, 0.8, 1, "Last action: None")
            end

            -- Configured Items + Add/Remove controls
            ensureLists()
            local keep = LOOT_CONFIG.items_to_keep
            local destroy = LOOT_CONFIG.items_to_destroy

            ImGui.Separator()

            -- Quick add from Cursor
            if mq.TLO.Cursor.ID() ~= nil then
                local cursorName = mq.TLO.Cursor.Name()
                ImGui.Separator()
                ImGui.TextColored(0.8, 0.8, 0.8, 1, string.format("Cursor: %s", cursorName))
                ImGui.SameLine()
                ImGui.PushID("##_small_btn_add_keep_cursor")
                if ImGui.SmallButton("Add Cursor to Keep") then
                    addKeep(cursorName, true)
                end
                ImGui.PopID()
                ImGui.SameLine()
                ImGui.PushID("##_small_btn_add_destroy_cursor")
                if ImGui.SmallButton("Add Cursor to Destroy") then
                    addDestroy(cursorName, true)
                end
                ImGui.PopID()
            end

            -- Keep list
            ImGui.SetNextItemOpen(true, ImGuiCond.Once)
            if ImGui.CollapsingHeader(string.format("Items to Keep (%d)", #keep)) then
                ImGui.BeginChild("keep_child", 0, 160, true)
                if #keep == 0 then
                    ImGui.TextDisabled("No items configured to keep.")
                else
                    for idx, itemName in ipairs(keep) do
                        ImGui.BulletText(itemName)
                        ImGui.SameLine()
                        ImGui.PushID("##_small_btn_remove_keep_" .. idx)
                        if ImGui.SmallButton("Remove") then
                            removeKeep(itemName, true) -- persist immediately
                        end
                        ImGui.PopID()
                    end
                end
                ImGui.EndChild()

                -- Typed Add/Remove for Keep
                ui.keepInput = readInputText("##keep_input", ui.keepInput)
                ImGui.SameLine()
                if ImGui.SmallButton("Add Keep") then
                    local kname = (ui.keepInput or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if kname ~= "" then
                        addKeep(kname, true)
                        ui.keepInput = ""
                    else
                        print("Keep: Enter an item name.")
                    end
                end
            end

            -- Destroy list
            ImGui.SetNextItemOpen(false, ImGuiCond.Once)
            if ImGui.CollapsingHeader(string.format("Items to Destroy (%d)", #destroy)) then
                ImGui.BeginChild("destroy_child", 0, 160, true)
                if #destroy == 0 then
                    ImGui.TextDisabled("No items configured to destroy.")
                else
                    for idx, itemName in ipairs(destroy) do
                        ImGui.BulletText(itemName)
                        ImGui.SameLine()
                        ImGui.PushID("##_small_btn_remove_destroy_" .. idx)
                        if ImGui.SmallButton("Remove") then
                            removeDestroy(itemName, true) -- persist immediately
                        end
                        ImGui.PopID()
                    end
                end
                ImGui.EndChild()

                -- Typed Add/Remove for Destroy
                ui.destroyInput = readInputText("##destroy_input", ui.destroyInput)
                ImGui.SameLine()
                if ImGui.SmallButton("Add Destroy") then
                    local dname = (ui.destroyInput or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if dname ~= "" then
                        addDestroy(dname, true)
                        ui.destroyInput = ""
                    else
                        print("Destroy: Enter an item name.")
                    end
                end
            end
        end
        ImGui.End()
    end
end

mq.imgui.init('CauldronGUI', CauldronGUI)

while true do
    if not pause_switch then
        -- Always handle/announce cursor items
        KeepItem()

        -- Only run the heavier scans/casting when appropriate
        if shouldRunCursorChecks() then
            DestroyInventory()
            CheckSpell()
            CheckCauldron()
        end

        mq.delay(250)
        mq.doevents()
    else
        mq.delay(250)
        mq.doevents()
    end
end
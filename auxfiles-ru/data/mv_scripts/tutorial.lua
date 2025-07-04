--[[
////////////////////
IMPORTS
////////////////////
]]--
local vter = mods.multiverse.vter
local time_increment = mods.multiverse.time_increment

--[[
////////////////////
DATA & CLASS DECLARATIONS
////////////////////
]]--
local TutorialManager = Hyperspace.Tutorial
local whiteColourRect = Graphics.GL_Color(1.0, 1.0, 1.0, 1.0)
local redColourRect = Graphics.GL_Color(1.0, 0.0, 0.0, 1.0)
local continueText = Hyperspace.TextString("tutorial_continue", false)
local continueBase = Hyperspace.Resources:GetImageId("tutorial/button_continue_base.png")

local TutorialLuaManager = {}
TutorialLuaManager.__index = TutorialLuaManager
mods.multiverse.TutorialLuaManager = TutorialLuaManager
local instance = nil

function TutorialLuaManager.new()
    if instance then
        return instance
    end
    local self = setmetatable({}, TutorialLuaManager)
    self.eventsList = {}
    self.currentEventKey = nil
    self.currentEvent = nil
    self.textBoxes = {}
    self.redArrows = {}
    self.redShapes = {}
    instance = self
    return self
end

function TutorialLuaManager:clear_event()
    if self.currentEvent then
        self.textBoxes = {}
        self.redArrows = {}
        self.redShapes = {}
        self.currentEvent = nil
    end
end

function TutorialLuaManager:start_event(key)
    if not TutorialManager.bRunning then return end
    self:clear_event()
    if self.eventsList[key] then
        self.currentEvent = self.eventsList[key]
        self.currentEventKey = key
        self.currentEvent:on_start()
    end
end

function TutorialLuaManager:update(dt)
    if self.currentEvent and self.currentEvent:on_loop() then
        local save = self.currentEvent
        self:clear_event()
        if save then save:on_stop() end
    end
    for _, textBox in ipairs(self.textBoxes) do
        textBox:update()
    end
    for _, redShapes in ipairs(self.redShapes) do
        redShapes:update()
    end
    local time = os.clock() * 6
    local sinValue = (math.sin(time) + 1) / 2
    redColourRect = Graphics.GL_Color(1.0, sinValue, sinValue, 1.0)
end

function TutorialLuaManager:render()
    for _, textBox in ipairs(self.textBoxes) do
        textBox:render()
    end
    for _, redArrows in ipairs(self.redArrows) do
        redArrows:OnRender()
    end
    for _, redShapes in ipairs(self.redShapes) do
        redShapes:render()
    end
end

function TutorialLuaManager:click()
    for _, textBox in ipairs(self.textBoxes) do
        if textBox.canskip and textBox.continueButton.bHover and textBox.continueButton.bActive then
            local save = self.currentEvent
            self:clear_event()
            if save then save:on_stop() end
        end
    end
end

function TutorialLuaManager:add_event(key, event)
    self.eventsList[key] = event
end

-- TutorialEvent class
local TutorialEvent = {}
TutorialEvent.__index = TutorialEvent
mods.multiverse.TutorialEvent = TutorialEvent

function TutorialEvent.new(on_start, on_stop, on_loop)
    local self = setmetatable({}, TutorialEvent)
    self.on_start = on_start or function() end
    self.on_stop = on_stop or function() end
    self.on_loop = on_loop or function() return false end
    return self
end

-- TextBox class
local TextBox = {}
TextBox.__index = TextBox
mods.multiverse.TextBox = TextBox

function TextBox.new(text, x, y, canskip)
    local self = setmetatable({}, TextBox)
    self.text = text
    self.continueButton = nil
    self.canskip = canskip
    self.x = x
    self.y = y
    self.width = 250
    self.height = Graphics.freetype.easy_measurePrintLines(12, 0, 0 , self.width - 20, self.text).y + 20
    self.window = Hyperspace.WindowFrame(0, 0, self.width, self.height)
    if self.canskip then
        self.continueButton = Hyperspace.TextButton()
        self.continueButton:OnInit(Hyperspace.Point(self.x + 65, self.y + self.height + 2), Hyperspace.Point(120,25), 2, continueText, 62)
    end
    return self
end

function TextBox:update()
    if self.canskip then
        local mousePos = Hyperspace.Mouse.position
        self.continueButton:MouseMove(mousePos.x, mousePos.y, false)
    end
end

function TextBox:render()
    self.window:Draw(self.x, self.y)
    Graphics.freetype.easy_printAutoNewlines(12, self.x + 13, self.y + 15, self.width - 20, self.text);
    if self.canskip then
        Hyperspace.Resources:RenderImage(continueBase, self.x + 43, self.y + self.height - 3, 0, whiteColourRect, 1.0, false)
        self.continueButton:OnRender()
    end
end

-- RectIndicator class
local RectIndicator = {}
RectIndicator.__index = RectIndicator
mods.multiverse.RectIndicator = RectIndicator

function RectIndicator.new(x, y, w, h, size)
    local self = setmetatable({}, RectIndicator)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.size = size or 4
    return self
end

function RectIndicator:update()
end

function RectIndicator:render()
    Graphics.CSurface.GL_DrawRectOutline(self.x, self.y, self.w, self.h, redColourRect, self.size)
end

--[[
////////////////////
LOGIC
////////////////////
]]--
local tutM = TutorialLuaManager.new()

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function()
    if TutorialManager.bRunning then
        tutM:click()
    end
    return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if TutorialManager.bRunning then
        tutM:update(time_increment(false))
    end
end)

script.on_render_event(Defines.RenderEvents.SHIP_STATUS, function() end, function()
    if TutorialManager.bRunning then
        tutM:render()
    end
end)

script.on_init(function()
    if TutorialManager.bRunning then
        tutM:start_event("tutorial_start")
    end
end)

--[[
////////////////////
TUTORIAL SCRIPT
////////////////////
]]--

--[[
Documentation for modders:

This script provides a framework for managing tutorial events in the FTL Multiverse mod. 
It allows modders to define, manage, and trigger custom tutorial events using the `TutorialManager` and `TutorialEvent` objects.

local TutorialLuaManager = mods.multiverse.TutorialLuaManager.new() (will give you back the instance of the tutorial manager created here)
local TutorialEvent = mods.multiverse.TutorialEvent
local TextBox = mods.multiverse.TextBox
local RectIndicator = mods.multiverse.RectIndicator

### TutorialManager Methods:

TutorialManager:add_event(key, event)
    key: the key to access the event
    event: the TutorialEvent object to be added

You can clobber existing tutorial event by using the same key, allowing you to insert new event in between existing ones

TutorialManager:start_event(key)
    key: the key of the event to start, will clear the current event

### TutorialEvent Constructor:

TutorialEvent.new(on_start, on_stop, on_loop)
    on_start: function to be called when the event starts
    on_stop: function to be called when the event stops
    on_loop: function to be called every frame, return true to stop the event

### TextBox Constructor:

TextBox.new(text, x, y, canskip)
    text: the text to be displayed in the box
    x: x position of the box
    y: y position of the box
    canskip: boolean to show if the event can be skipped manually or not, create a continue button

### RectIndicator Constructor:

RectIndicator.new(x, y, w, h, size)
    x: x position of the rectangle
    y: y position of the rectangle
    w: width of the rectangle
    h: height of the rectangle
    size: size of the outline, default is 4

### TutoralArrow Constructor:

Hyperspace.TutorialArrow(Hyperspace.Pointf(x, y), angle)
    position: x and y position of the arrow
    angle: angle of the arrow

Don't hesitate to copy from the existing code to create your own tutorial events, that will make your life easier!
]]--
local checkValidated = false
local checkToggle = false
local storageCheck = false
local fightCheck = false
local checkDeadEnemy = false
local delay = 0
local repeatExit = false
local atlasCheck = false
local forceSectorJump = false

tutM:add_event("tutorial_start", TutorialEvent.new(
    function()
        local textBox = TextBox.new(Hyperspace.Text:GetText("tutorial_start"), 850, 50, true)
        table.insert(tutM.textBoxes, textBox)
        TutorialManager.bAllowJumping = false

        -- Reseting the values at the start
        checkValidated = false
        checkToggle = false
        storageCheck = false
        fightCheck = false
        checkDeadEnemy = false
        delay = 0
        repeatExit = false
        atlasCheck = false
        forceSectorJump = false
    end,
    function()
        tutM:start_event("tutorial_crew_power")
    end,
    function()
        return false
    end
))

-- Crew Power
tutM:add_event("tutorial_crew_power", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_crew_power"), 123, 222, false))
        table.insert(tutM.redShapes, RectIndicator.new(3, 151, 97, 34))
        table.insert(tutM.redArrows, Hyperspace.TutorialArrow(Hyperspace.Pointf(155, 150), 180))

        -- Gives full charge to the crew powers
        for crew in vter(Hyperspace.ships.player.vCrewList) do
            for power in vter(crew.extend.crewPowers) do
                power.powerCooldown.first = power.powerCooldown.second
            end
        end
    end,
    function()
        checkValidated = false
        tutM:start_event("tutorial_toggle_1")
    end,
    function()
        if checkValidated then return true end
        return false
    end
))

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function()
    if TutorialManager.bRunning and tutM.currentEventKey == "tutorial_crew_power" then
        checkValidated = true
    end
    return Defines.Chain.CONTINUE
end)

-- Weapon/Drone Toggles
tutM:add_event("tutorial_toggle_1", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_toggle_1"), 123, 173, false))
        table.insert(tutM.redShapes, RectIndicator.new(107, 111, 37, 40))
        table.insert(tutM.redArrows, Hyperspace.TutorialArrow(Hyperspace.Pointf(158, 110), 180))
        checkToggle = true

        -- Enable the button
        Hyperspace.CustomEventsParser.GetInstance():LoadEvent(Hyperspace.App.world, "TUTORIAL_UI_TOGGLE_BUTTON", true, 9999)
    end,
    function()
    end,
    function()
        return false
    end
))

tutM:add_event("tutorial_toggle_2", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_toggle_2"), 970, 5, false))
    end,
    function()
        checkToggle = false
        tutM:start_event("tutorial_info_button")
    end,
    function()
        if (not Hyperspace.App.gui.choiceBoxOpen) then return true end
        return false
    end
))
script.on_game_event("COMBAT_CHECK_TOGGLE", false, function() if (checkToggle) then tutM:start_event("tutorial_toggle_2") end end)

-- Bottom Right Info Button
tutM:add_event("tutorial_info_button", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_info_button"), 956, 312, true))
        table.insert(tutM.redShapes, RectIndicator.new(1211, 658, 47, 48))
        table.insert(tutM.redArrows, Hyperspace.TutorialArrow(Hyperspace.Pointf(1152, 535), 90))
    end,
    function()
        tutM:start_event("tutorial_crew_order")
    end,
    function()
        return false
    end
))

-- Crew Reorder
tutM:add_event("tutorial_crew_order", TutorialEvent.new(
    function()
        -- Give two more crew here
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_crew_order"), 123, 222, true))
        table.insert(tutM.redShapes, RectIndicator.new(4, 152, 97, 93))
        table.insert(tutM.redArrows, Hyperspace.TutorialArrow(Hyperspace.Pointf(115, 150), 180))
    end,
    function()
        tutM:start_event("tutorial_tile_control")
    end,
    function()
        return false
    end
))

-- Crew Tile Control
tutM:add_event("tutorial_tile_control", TutorialEvent.new(
    function()
        local textBox = TextBox.new(Hyperspace.Text:GetText("tutorial_tile_control"), 123, 222, true)
        table.insert(tutM.textBoxes, textBox)
        table.insert(tutM.redShapes, RectIndicator.new(618, 275, 35, 35, 1))
        table.insert(tutM.redShapes, RectIndicator.new(653, 275, 35, 35, 1))
        table.insert(tutM.redShapes, RectIndicator.new(618, 310, 35, 35, 1))
        table.insert(tutM.redShapes, RectIndicator.new(653, 310, 35, 35, 1))
        table.insert(tutM.redArrows, Hyperspace.TutorialArrow(Hyperspace.Pointf(700, 270), 180))
    end,
    function()
        tutM:start_event("tutorial_storage_initial") -- Skipping system price
    end,
    function()
        return false
    end
))

-- Storage Button
tutM:add_event("tutorial_storage_initial", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_storage_initial"), 801, 26, false))
        table.insert(tutM.redShapes, RectIndicator.new(705, 23, 69, 50))
        table.insert(tutM.redArrows, Hyperspace.TutorialArrow(Hyperspace.Pointf(650, 150), 270))
        storageCheck = true

        -- Enable the button
        Hyperspace.CustomEventsParser.GetInstance():LoadEvent(Hyperspace.App.world, "TUTORIAL_UI_STORAGE_CHECK_BUTTON", true, 9999)
    end,
    function()
    end,
    function()
        return false
    end
))

-- [[lots of callbacks for each storage event, infinite loop]]

tutM:add_event("tutorial_storage_main", TutorialEvent.new(
    function()
        if Hyperspace.ships.player.currentScrap == 0 then
            Hyperspace.ships.player:ModifyScrapCount(200, true)
        end
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_storage_main"), 970, 220, false))
    end,
    function()
        storageCheck = false
        tutM:start_event("tutorial_fight_start")
    end,
    function()
        if (not Hyperspace.App.gui.choiceBoxOpen) then return true end
        return false
    end
))
script.on_game_event("STORAGE_CHECK_BUTTON", false, function() if (storageCheck) then tutM:start_event("tutorial_storage_main") end end)

tutM:add_event("tutorial_storage_mission", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_storage_mission"), 970, 220, false))
    end,
    function()
        storageCheck = false
        tutM:start_event("tutorial_fight_start")
    end,
    function()
        if (not Hyperspace.App.gui.choiceBoxOpen) then return true end
        return false
    end
))
script.on_game_event("STORAGE_CHECK_STATUS", false, function() if (storageCheck) then tutM:start_event("tutorial_storage_mission") end end)

tutM:add_event("tutorial_storage_system", TutorialEvent.new(
    function()
        Hyperspace.ships.player.fuel_count = 10
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_storage_system"), 970, 220, false))
    end,
    function()
        storageCheck = false
        tutM:start_event("tutorial_fight_start")
    end,
    function()
        if (not Hyperspace.App.gui.choiceBoxOpen) then return true end
        return false
    end
))
script.on_game_event("STORAGE_CHECK_SYSTEM", false, function() if (storageCheck) then tutM:start_event("tutorial_storage_system") end end)

tutM:add_event("tutorial_storage_lab", TutorialEvent.new(
    function()
        Hyperspace.ships.player.fuel_count = 10
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_storage_lab"), 970, 220, false))
    end,
    function()
        storageCheck = false
        tutM:start_event("tutorial_fight_start")
    end,
    function()
        if (not Hyperspace.App.gui.choiceBoxOpen) then return true end
        return false
    end
))
script.on_game_event("STORAGE_CHECK_LAB_INSTALL", false, function() if (storageCheck) then tutM:start_event("tutorial_storage_lab") end end)
script.on_game_event("STORAGE_CHECK_LAB", false, function() if (storageCheck) then tutM:start_event("tutorial_storage_lab") end end)

-- Fight: Jump
tutM:add_event("tutorial_fight_start", TutorialEvent.new(
    function()
        Hyperspace.ships.player.fuel_count = 3
        TutorialManager.bAllowJumping = true
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_fight_start"), 970, 220, false))
        table.insert(tutM.redArrows, Hyperspace.TutorialArrow(Hyperspace.Pointf(495, 145), 270))
        fightCheck = true
    end,
    function()
    end,
    function()
        if (Hyperspace.App.world.starMap.bOpen) then
            tutM.redShapes = {}
            tutM.redArrows = {}
        end
        return false
    end
))
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function() if fightCheck then tutM.textBoxes = {} end end)

-- Fight: Combat check and combat augment
tutM:add_event("tutorial_fight_check", TutorialEvent.new(
    function()
        TutorialManager.bAllowJumping = false
        fightCheck = false
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_fight_check"), 970, 220, false))
    end,
    function()
        tutM:start_event("tutorial_fight_icon")
    end,
    function()
        if (not Hyperspace.App.gui.choiceBoxOpen) then return true end --Closed the fight check
        return false
    end
))
script.on_game_event("COMBAT_CHECK", false, function() if (fightCheck) then tutM:start_event("tutorial_fight_check") end end)

-- Fight: Enemy Icons
tutM:add_event("tutorial_fight_icon", TutorialEvent.new(
    function()
        Hyperspace.CustomEventsParser.GetInstance():LoadEvent(Hyperspace.App.world, "TUTORIAL_QUEST_LOAD", true, 9999) -- Load the [!] quest
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_fight_icon"), 970, 220, false))
        table.insert(tutM.redShapes, RectIndicator.new(1239, 487, 40, 40))
        table.insert(tutM.redArrows, Hyperspace.TutorialArrow(Hyperspace.Pointf(1065, 487), 0))
        checkDeadEnemy = true
        delay = 0
    end,
    function()
    end,
    function()
        if Hyperspace.Mouse.position.x >= 1239 and Hyperspace.Mouse.position.x <= 1279 and Hyperspace.Mouse.position.y >= 487 and Hyperspace.Mouse.position.y <= 527 then
            delay = delay + time_increment(false)
        end
        if delay >= 1 then
            tutM.textBoxes = {}
            tutM.redShapes = {}
            tutM.redArrows = {}
        end
        if Hyperspace.ships.enemy and Hyperspace.ships.enemy.bDestroyed then
            tutM.textBoxes = {}
            tutM.redShapes = {}
            tutM.redArrows = {}
        end
        return false
    end
))

-- Empty Beacon
tutM:add_event("tutorial_empty_beacon", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_empty_beacon"), 970, 220, false))
        checkDeadEnemy = false
    end,
    function()
        tutM:start_event("tutorial_notoriety_change")
    end,
    function()
        if (not Hyperspace.App.gui.choiceBoxOpen) then return true end --Close the event
        return false
    end
))
script.on_game_event("STORAGE_CHECK", false, function() if (checkDeadEnemy) then tutM:start_event("tutorial_empty_beacon") end end)

-- Notoriety
tutM:add_event("tutorial_notoriety_change", TutorialEvent.new(
    function()
        Hyperspace.CustomEventsParser.GetInstance():LoadEvent(Hyperspace.App.world, "MORALITY_UPDATE_GENERAL_DOUBLE", true, 9999) -- Notoriety event
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_notoriety_change"), 970, 180, false))

        -- Change sector name
        for sector in vter(Hyperspace.App.world.starMap.sectors) do
            sector.description.name.data = sector.description.name:GetText() .. " [!]"
            sector.description.name.isLiteral = true
            sector.description.shortName.data = sector.description.shortName:GetText() .. " [!]"
            sector.description.shortName.isLiteral = true
        end
    end,
    function()
        tutM:start_event("tutorial_map_open")
    end,
    function()
        if (not Hyperspace.App.gui.choiceBoxOpen) then return true end --Close the event
        return false
    end
))

-- Starmap: Open
tutM:add_event("tutorial_map_open", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_map_open"), 643, 109, false))
        table.insert(tutM.redArrows, Hyperspace.TutorialArrow(Hyperspace.Pointf(495, 145), 270))
        TutorialManager.bAllowJumping = true
        Hyperspace.ships.player.fuel_count = 10
        repeatExit = true
        for loc in vter(Hyperspace.App.world.starMap.locations) do
            loc.beacon = false
        end
        Hyperspace.App.world.starMap.currentLoc.beacon = true
    end,
    function()
        tutM:start_event("tutorial_map_immune_beacon")
    end,
    function()
        if (Hyperspace.App.world.starMap.bOpen) then return true end
        return false
    end
))
tutM:add_event("tutorial_map_open_repeat", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_map_open"), 643, 109, false))
        TutorialManager.bAllowJumping = true
        Hyperspace.ships.player.fuel_count = 10
        for loc in vter(Hyperspace.App.world.starMap.locations) do
            loc.beacon = false
        end
        Hyperspace.App.world.starMap.currentLoc.beacon = true
    end,
    function()
        tutM:start_event("tutorial_map_immune_beacon")
    end,
    function()
        if (Hyperspace.App.world.starMap.bOpen) then return true end
        return false
    end
))
script.on_game_event("COMBAT_CHECK", false, function() if (repeatExit) then tutM:start_event("tutorial_map_open_repeat") end end)

-- Starmap: Fleet Immune Beacon
tutM:add_event("tutorial_map_immune_beacon", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_map_immune_beacon"), 65, 174, false))
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_map_immune_beacon_jump"), 850, 5, false))
        forceSectorJump = true
    end,
    function()
        tutM:start_event("tutorial_map_sector_choice")
    end,
    function()
        if (Hyperspace.App.world.starMap.bChoosingNewSector) then return true end
        return false
    end
))

-- 840 85
-- 1092 140
script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function()
    if TutorialManager.bRunning and forceSectorJump then
        local x, y = Hyperspace.Mouse.position.x, Hyperspace.Mouse.position.y
        return (x >= 840 and x <= 1092 and y >= 85 and y <= 140) and Defines.Chain.CONTINUE or Defines.Chain.PREEMPT
    end
    return Defines.Chain.CONTINUE
end)

-- Starmap: Unique Sector
tutM:add_event("tutorial_map_sector_choice", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_map_sector_choice"), 65, 246, false))
        atlasCheck = true
    end,
    function()
    end,
    function()
        forceSectorJump = Hyperspace.App.world.starMap.bOpen and not Hyperspace.App.world.starMap.bChoosingNewSector
        return false
    end
))
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function() if atlasCheck then tutM.textBoxes = {} end forceSectorJump = false end)

-- Starmap: Atlas start
tutM:add_event("tutorial_map_atlas", TutorialEvent.new(
    function()
        Hyperspace.CustomEventsParser.GetInstance():LoadEvent(Hyperspace.App.world, "CLOBBER_ATLAS_MENU", true, 9999)
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_map_atlas"), 982, 186, false))
        repeatExit = false
    end,
    function()
    end,
    function()
        return false
    end
))
script.on_game_event("LOAD_ATLAS_MARKER", false, function() if (atlasCheck) then tutM:start_event("tutorial_map_atlas") end end)

-- Starmap: Atlas Augment
tutM:add_event("tutorial_map_atlas_augment", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_map_atlas_augment"), 970, 220, false))
        TutorialManager.bAllowJumping = false
    end,
    function()
    end,
    function()
        return false
    end
))
script.on_game_event("TUTORIAL_ATLAS_EQUIPMENT", false, function() if (atlasCheck) then tutM:start_event("tutorial_map_atlas_augment") end end)
script.on_game_event("TUTORIAL_ATLAS_MENU_NOEQUIPMENT", false, function() tutM.textBoxes = {} end)

-- Starmap: Atlas Reroute
tutM:add_event("tutorial_map_atlas_reroute", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_map_atlas_reroute"), 970, 220, false))
    end,
    function()
    end,
    function()
        return false
    end
))
script.on_game_event("TUTORIAL_REROUTE_MENU", false, function() if (atlasCheck) then tutM:start_event("tutorial_map_atlas_reroute") end end)
script.on_game_event("TUTORIAL_LIGHTSPEED_SECTOR_WARP", false, function() tutM.textBoxes = {} end)

-- Guard
tutM:add_event("tutorial_guard", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_guard"), 970, 220, false))
    end,
    function()
        atlasCheck = false
        tutM:start_event("tutorial_end")
    end,
    function()
        if (not Hyperspace.App.gui.choiceBoxOpen
            and Hyperspace.ships.enemy
            and (Hyperspace.ships.enemy.bDestroyed
            or not Hyperspace.ships.enemy._targetable.hostile))
        then return true end
        if (Hyperspace.ships.enemy._targetable.hostile) then tutM.textBoxes = {} end
        return false
    end
))
script.on_game_event("GUARD_FEDERATION", false, function() if (atlasCheck) then tutM:start_event("tutorial_guard") end end)

-- Ending stuff, very emotional
tutM:add_event("tutorial_end", TutorialEvent.new(
    function()
        table.insert(tutM.textBoxes, TextBox.new(Hyperspace.Text:GetText("tutorial_end"), 970, 220, true))
    end,
    function()
        -- Quit the tutorial
        TutorialManager.bQuitTutorial = true
    end,
    function()
        return false
    end
))
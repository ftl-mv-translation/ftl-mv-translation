--[[
////////////////////
IMPORTS
////////////////////
]]--
-- This is a neat way of bringing the functions declared earlier into the local scope, so that they can be used under the names "screen_fade" and "screen_shake" instead of their full names. It is also technically faster to declare functions as locals in some cases, but that isn't really of importance here.
local vter = mods.multiverse.vter
local string_starts = mods.multiverse.string_starts
local screen_fade = mods.multiverse.screen_fade
local screen_shake = mods.multiverse.screen_shake
local on_load_game = mods.multiverse.on_load_game

--[[
////////////////////
UTILITY FUNCTIONS
////////////////////
]]--

--Remember to use local functions when they are only used within the scope of declaration.
local function reset_title() --Using a function for this is kind of weird, but it's how it was done before and it allows for a different default name to be used if you wanted.
    Hyperspace.setWindowTitle("FTL: Multiverse")
end

local function do_nothing() end

--[[
////////////////////
HER QUEST STUFF
////////////////////
]]--

script.on_game_event("ANOMALY_ORACLE_SPEAK", false, function()
    Hyperspace.setWindowTitle("Vérifiez le message d'erreur :)")  --Here we set the title of the window, and then quickly reset it. Why is that? This is because when an error message pops up from Hyperspace.ErrorMessage, nothing is run until after the message is closed. This way, we only tell the player to "Check the error message" for as long as the message is open.
    Hyperspace.ErrorMessage("Ne faites confiance ni au marchand, ni à ses complices. Ne faites confiance qu'à moi et aux Observateurs, informez Thest de cela. Ils vous aideront. Venez me trouver. Et quoi que vous fassiez, il est très important que vous n'en parliez pas à celui qui porte le costume. Nous en discuterons plus en détail lorsque nous nous rencontrerons.")
    reset_title()
    log(string.rep("Trouvez-moi Trouvez-moi Trouvez-moi Trouvez-moi Trouvez-moi Trouvez-moi Trouvez-moi Trouvez-moi Trouvez-moi Trouvez-moi Trouvez-moi Trouvez-moi Trouvez-moi\n", 99))
end)

script.on_game_event("SHES_MAD", false, function()
    Hyperspace.ErrorMessage("Euh, excusez-moi ? Qu'est-ce que vous dites ? Nous avions un PLAN, et ce n'était pas celui-là.!")
    Hyperspace.setWindowTitle(">:(")
end)

script.on_game_event("SHE_KILLED_YOU", false, function()
    Hyperspace.ErrorMessage("La seule façon dont tu aurais pu gagner, idiot, c'était de travailler avec moi. Haha ! Haha ! Haha ! Haha ! Haha ! Haha ! Haha ! Haha ! Haha ! Haha ! Haha !")
    for i = 1, 5 do Hyperspace.ErrorMessage("Haha ! Haha ! Haha ! Haha ! Haha ! Haha ! Haha ! Haha ! Haha ! Haha !") end --Here we repeat a function 5 times instead of writing it out multiple times. The word "for" can be used for iteration in this way. For example, "for i = 5, 1, -1 do print(i) end" will print "5 4 3 2 1".
    Hyperspace.setWindowTitle(string.rep(":) ", 66)) --Here we repeat the string ":) " 66 times.
end)

do --Here we keep the variables "titleSet" and "herVirus" only where they are needed.
    local titleSet = false
    local herVirus = false
    script.on_game_event("SHE_WINS", false, function()
        Hyperspace.ErrorMessage("Haha! J'ai gagné!")
        herVirus = true
        titleSet = false
    end)

    script.on_render_event(Defines.RenderEvents.MAIN_MENU, do_nothing, function()
        if not titleSet then
            titleSet = true
            if herVirus then
                Hyperspace.setWindowTitle("FTL: Multiverse :)")
            else
                reset_title()
            end
        end
    end)
end

--Here we can see how our earlier functions are useful. We can easily tell what is happening just from reading the functions. They use intuitive units (seconds) which means we can easily coordinate them with the xml.
script.on_game_event("NEXUS_ENDING_GOOD_FADE", false, function() --For example, at "NEXUS_ENDING_GOOD_FADE" we shake the screen for 3 seconds, start a fade to white (RGB of 1,1,1) that will last 3 seconds, and reset the title.
    screen_shake(3) 
    screen_fade(Graphics.GL_Color(1, 1, 1, 1), 1.5, 1.5, 1.5) --Functions where the only argument is a table constructor can be called with "Function({key = value, otherkey = othervalue,...})", but the parenthesis may be omitted and the function may be called as "Function{key = value, otherkey = othervalue,...}".
    reset_title()
end)


script.on_game_event("NEXUS_ENDING_BAD_FADE", false, function()
    screen_fade(Graphics.GL_Color(0.75, 0, 0, 1)) --Here we start a fade to red that will last 3 seconds, such that the transition at 2 seconds is masked
end)

script.on_game_event("NEXUS_HER_REVEAL_FADE", false, function()
    screen_shake(3.7) --Here we shake the screen for 3.7 seconds, and start a fade to black that will mask the transition before fading out for one second. This is just long enough for the triggered event to happen, so we can easily tell that our effects are synchronized just by looking at the timer.
    screen_fade(Graphics.GL_Color(0, 0, 0, 1), 2, 1.7, 1)
end)


script.on_game_event("HER_FINALE", false, function()
    screen_shake(3) --Here we have a 3 second screenshake and a 4.5 second fade to white that will mask the transition at 3 seconds.
    screen_fade(Graphics.GL_Color(1, 1, 1, 1), 1.5, 1.5)
end)
script.on_game_event("HER_FINALE_REAL", false, function()
    Hyperspace.ErrorMessage("Je n'arrive vraiment pas à croire que tu m'aies trahi comme ça, Renégad ! J'étais si près... si près de quelque chose de si parfait. J'espère que tu es heureux, dans ton multivers stérile et ennuyeux, sous le joug d'une bande de parasites communs. >:(")
end)

--[[
////////////////////
CUSTOM BUTTON HOTKEYS
////////////////////
]]--

-- Initialize hotkeys
script.on_init(function()
    if Hyperspace.metaVariables.prof_hotkey_toggle == 0 then Hyperspace.metaVariables.prof_hotkey_toggle = 91 end
    if Hyperspace.metaVariables.prof_hotkey_storage == 0 then Hyperspace.metaVariables.prof_hotkey_storage = 93 end
end)

-- Track when the hotkeys are being configured
local settingToggle = false
local settingStorage = false
script.on_game_event("COMBAT_CHECK_HOTKEYS_TOGGLE_START", false, function() settingToggle = true end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_TOGGLE_END_1", false, function() settingToggle = false end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_TOGGLE_END_2", false, function() settingToggle = false end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_STORAGE_START", false, function() settingStorage = true end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_STORAGE_END_1", false, function() settingStorage = false end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_STORAGE_END_2", false, function() settingStorage = false end)

script.on_internal_event(Defines.InternalEvents.ON_KEY_DOWN, function(key)
    -- Allow player to reconfigure the hotkeys
    if settingToggle then Hyperspace.metaVariables.prof_hotkey_toggle = key end
    if settingStorage then Hyperspace.metaVariables.prof_hotkey_storage = key end
    
    -- Do stuff if a hotkey is pressed
    local cmdGui = Hyperspace.App.gui
    if Hyperspace.ships.player and not (Hyperspace.ships.player.bJumping or cmdGui.event_pause or cmdGui.menu_pause) then
        local world = Hyperspace.App.world
        if key == Hyperspace.metaVariables.prof_hotkey_toggle then -- Toggle menu
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(world, "COMBAT_CHECK_TOGGLE_BUTTON", false, -1)
        elseif key == Hyperspace.metaVariables.prof_hotkey_storage and (Hyperspace.Tutorial.bRunning or cmdGui.upgradeButton.bActive) then -- Storage menu
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(world, "STORAGE_CHECK_BUTTON", false, -1)
        end
    end
end)

--[[
////////////////////
SURRENDER REMOVES INCOMING PROJECTILES
////////////////////
]]--

function mods.multiverse.destroy_all_projectiles()
    local projectiles = Hyperspace.App.world.space.projectiles
    for i = 0, projectiles:size() - 1 do
        local projectile = projectiles[i]
        local projName = tostring(projectile.extend.name)
        if not (projName == "" or projName == "nil" or projName == "PDS_SHOT") then
            projectile:Kill()
        end
    end
end

script.on_game_event("CURA_SCANDAL_WIN", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("CYRA_JERRY_SUCCESS", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("RELOCATION_SURRENDER", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDERED_ALKALI", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("ANOINTED_SURRENDER_ACCEPT", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDERED_TO_SYLVAN", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SYLVAN_SURRENDERED", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SYLVAN_PRIME_SURRENDER", false, mods.multiverse.destroy_all_projectiles)

script.on_game_event("SURRENDER_ACCEPT", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_FEDERATION_ACCEPT", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_NOTHING", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_REBEL_DELAY", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_AUTO_FUEL_ACCEPT", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_ENGI_ACCEPT", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_ENGI_STONKS", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_ENGI_STONKS2", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_ZOLTAN_NONSENSE", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_CRYSTAL_STONKS", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_CRYSTAL_PAY", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_HACKER_ACCEPT", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_ROCK_MISSILES_ACCEPT", false, mods.multiverse.destroy_all_projectiles)
script.on_game_event("SURRENDER_OUTCAST_ACCEPT", false, mods.multiverse.destroy_all_projectiles)

--[[
////////////////////
MOVE PRIORITY QUESTS LEFT
////////////////////
]]--

-- All quests that need to be moved to the left side of the star map
-- eventName: The name of the event that needs to be moved
-- sectorName: The name of the sector where the event is located
-- sectorStartName: The name of the event triggered when entering the sector (used to trigger the swap)
--                  This event is also excluded from the list of valid locations to swap
-- swapTrackerVar: The playerVariable storing the index of the location to swap with for save/load (initialize to -1 in hyperspace.xml)
-- swapValidator: A function that checks if a location is valid for swapping, if the location is valid return true, the sectorStartName location is always invalid
mods.multiverse.leftSideQuests = {
    {
        eventName = "NEBULA_LIGHT_STARGROVE_LISTENING_POST_QUEST",
        sectorName = "SECTOR_STARGROVE_UNIQUE",
        sectorStartName = "ENTER_STARGROVE",
        swapTrackerVar = "loc_swap_index_mafan",
        swapValidator = function(loc)
            return string_starts(loc.event.eventName, "NEBULA_LIGHT")
        end
    }
}
local leftSideQuests = mods.multiverse.leftSideQuests

do
    -- Handle swap if needed
    local function check_left_side_quest(leftSideQuestData)
        local map = Hyperspace.App.world.starMap
        local leftSideQuestLoc = nil

        for loc in vter(map.locations) do
            if loc.event.eventName == leftSideQuestData.eventName then
                leftSideQuestLoc = loc
                break
            end
        end

        if not leftSideQuestLoc then return end

        local switchIndex = Hyperspace.playerVariables[leftSideQuestData.swapTrackerVar]
        if switchIndex > -1 then
            leftSideQuestLoc.event, map.locations[switchIndex].event = map.locations[switchIndex].event, leftSideQuestLoc.event
            return
        end

        -- No existing switch index, so we need to find a new location
        if leftSideQuestLoc.loc.x < 335 then return end

        -- Select all valid locations to swap with (left of the map and whatever additional conditions of the validator)
        local leftLocIndexes = {}
        for i = 0, map.locations:size() - 1 do
            local loc = map.locations[i]
            if loc.loc.x < 335 and (not leftSideQuestData.swapValidator or leftSideQuestData.swapValidator(loc)) and not (loc.event.eventName == leftSideQuestData.sectorStartName) then
                table.insert(leftLocIndexes, i)
            end
        end

        -- Select a random valid location to swap with and store the index to handle save/load
        if #leftLocIndexes > 0 then
            local randLocIndex = leftLocIndexes[math.random(#leftLocIndexes)]
            Hyperspace.playerVariables[leftSideQuestData.swapTrackerVar] = randLocIndex
            leftSideQuestLoc.event, map.locations[randLocIndex].event = map.locations[randLocIndex].event, leftSideQuestLoc.event
        end
    end

    -- Execute swap on entering sector
    for _, leftSideQuestData in ipairs(leftSideQuests) do
        script.on_game_event(leftSideQuestData.sectorStartName, false, function()
            check_left_side_quest(leftSideQuestData)
        end)
    end

    -- Execute swap on loading game if a swap index is stored
    on_load_game(function()
        for _, leftSideQuestData in ipairs(leftSideQuests) do
            if Hyperspace.App.world.starMap.currentSector.description.type == leftSideQuestData.sectorName then
                check_left_side_quest(leftSideQuestData)
            else
                Hyperspace.playerVariables[leftSideQuestData.swapTrackerVar] = -1
            end
        end
    end)
end

--[[
////////////////////
SHOW DYNASTY RUIN
////////////////////
]]--

script.on_game_event("ENTER_DYNASTY_UNIQUE", false, function()
    if Hyperspace.ships.player:HasEquipment("JUDGE_BOON_AETHER") > 0 then
        for loc in vter(Hyperspace.App.world.starMap.locations) do
            if loc.event.eventName == "NEBULA_DYNASTY_SPECIALRUIN" then
                loc.known = true
                return
            end
        end
    end
end)

--[[
////////////////////
SPAWN INFERNUM DEFECTOR
////////////////////
]]--

script.on_game_event("QUEST_STARGROVE_GRAVASTAR_MONK_MESSAGE", false, function()
    local bp = Hyperspace.Blueprints:GetCrewBlueprint("zoltan_infernum_defector")
    local rm = Hyperspace.ships.enemy:GetSystemRoom(6)
    Hyperspace.ships.enemy:AddCrewMemberFromBlueprint(bp, 0, true, rm, true)
end)

--[[
////////////////////
REALITY MANIPULATOR
////////////////////
]]--

-- Fix background changing from clearing hazard
local cachedBackground
script.on_game_event("COMBAT_CHECK_HAZARD", false, function()
    cachedBackground = Hyperspace.App.world.space.currentBack
end)
do
    local function reset_background()
        Hyperspace.App.world.space.currentBack = cachedBackground
        cachedBackground = nil
    end
    script.on_game_event("COMBAT_CHECK_HAZARD_ASTEROID", false, reset_background)
    script.on_game_event("COMBAT_CHECK_HAZARD_SUN", false, reset_background)
    script.on_game_event("COMBAT_CHECK_HAZARD_BLUEGIANT", false, reset_background)
    script.on_game_event("COMBAT_CHECK_HAZARD_PULSAR", false, reset_background)
    script.on_game_event("COMBAT_CHECK_HAZARD_IONSTORM", false, reset_background)
    script.on_game_event("COMBAT_CHECK_HAZARD_GRAVASTAR", false, reset_background)
end

-- Unlock for blue giant
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if Hyperspace.playerVariables.loc_environment_blue_giant > 0 and Hyperspace.metaVariables.prof_reality_unlock_bluegiant <= 0 and ship.iShipId == 0 and ship:HasAugmentation("COMBAT_HAZARD") > 0 then
        Hyperspace.metaVariables.prof_reality_unlock_bluegiant = 1
    end
end)

--[[
////////////////////
OTHER EVENTS
////////////////////
]]--

script.on_game_event("QUIT_GAME", false, function() Hyperspace.App:OnRequestExit() end)

--[[
////////////////////
COMBAT AUGMENT IN STORM
////////////////////
]]--

local function storm_combat_reactor()
    local spaceManager = Hyperspace.App.world.space
    local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
    local halfPower = math.ceil(powerManager.currentPower.second/2)

    if spaceManager.bStorm then
        if powerManager.iTempPowerLoss > 0 then
            powerManager.iTempPowerCap = halfPower - powerManager.iTempPowerLoss
            powerManager.iTempDividePower = 1
        end
    end
end

-- The clear reactor happens when the choicebox is closed so we are forced to check it on loop
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local spaceManager = Hyperspace.App.world.space
    local powerManager = Hyperspace.PowerManager.GetPowerManager(0)

    if spaceManager.bStorm and powerManager.iTempPowerCap == 1000 then
        powerManager.iTempPowerCap = math.ceil(powerManager.currentPower.second/2)
        powerManager.iTempDividePower = 2
    end
end)

script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, storm_combat_reactor)

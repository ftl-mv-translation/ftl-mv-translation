--[[
////////////////////
IMPORTS
////////////////////
]]--
-- This is a neat way of bringing the functions declared earlier into the local scope, so that they can be used under the names "screen_fade" and "screen_shake" instead of their full names. It is also technically faster to declare functions as locals in some cases, but that isn't really of importance here.
local screen_fade = mods.multiverse.screen_fade
local screen_shake = mods.multiverse.screen_shake

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
    Hyperspace.setWindowTitle("Проверь сообщение об ошибке :)")  --Here we set the title of the window, and then quickly reset it. Why is that? This is because when an error message pops up from Hyperspace.ErrorMessage, nothing is run until after the message is closed. This way, we only tell the player to "Check the error message" for as long as the message is open.
    Hyperspace.ErrorMessage("Не доверяйте ни этому торговцу, ни его сообщникам. Верьте только мне и наблюдателям, сообщите об этом Сесту. Вам помогут. Найдите меня. И, что бы вы ни делали, ни в коем случае не говорите тому, кто в костюме, об этом. Мы обсудим это подробнее, когда встретимся.")
    reset_title()
    log(string.rep("Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня\n", 99))
end)

script.on_game_event("SHES_MAD", false, function()
	Hyperspace.ErrorMessage("Эм, прости? Что это было? У нас был ПЛАН, и это не он!")
	Hyperspace.setWindowTitle(">:(")
end)

script.on_game_event("SHE_KILLED_YOU", false, function()
	Hyperspace.ErrorMessage("Единственный для тебя способ победить, глупыш, было работать со мной. Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе!")
	for i = 1, 5 do Hyperspace.ErrorMessage("Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе!") end --Here we repeat a function 5 times instead of writing it out multiple times. The word "for" can be used for iteration in this way. For example, "for i = 5, 1, -1 do print(i) end" will print "5 4 3 2 1".
	Hyperspace.setWindowTitle(string.rep(":) ", 66)) --Here we repeat the string ":) " 66 times.
end)

do --Here we keep the variables "titleSet" and "herVirus" only where they are needed.
	local titleSet = false
	local herVirus = false
	script.on_game_event("SHE_WINS", false, function()
		Hyperspace.ErrorMessage("Хахе! Я победила!")
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
	Hyperspace.ErrorMessage("Я правда не верю, что ты мог меня так предать, Ренегат! Я была так близко... так близко к такому совершенству. Я надеюсь, теперь ты доволен, в своей стерильной и скучной Мультивселенной, живя при режиме каких-то простых садовых вредителей. >:(")
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
    local cmdGui = Hyperspace.Global.GetInstance():GetCApp().gui
    if Hyperspace.ships.player and not (Hyperspace.ships.player.bJumping or cmdGui.event_pause or cmdGui.menu_pause) then
        local world = Hyperspace.Global.GetInstance():GetCApp().world
        if key == Hyperspace.metaVariables.prof_hotkey_toggle then -- Toggle menu
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(world, "COMBAT_CHECK_TOGGLE_BUTTON", false, -1)
        elseif key == Hyperspace.metaVariables.prof_hotkey_storage and cmdGui.upgradeButton.bActive then -- Storage menu
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
    local projectiles = Hyperspace.Global.GetInstance():GetCApp().world.space.projectiles
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
OTHER EVENTS
////////////////////
]]--

script.on_game_event("QUIT_GAME", false, function() Hyperspace.Global.GetInstance():GetCApp():OnRequestExit() end)

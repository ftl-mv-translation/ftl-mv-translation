--initialize the multiverse table - necessary so addond devs don't do something stupid with the same variables
mods.multiverse = {}

--variables
mods.multiverse.herVirus = false
--for fadeWhite
mods.multiverse.canFadeWhite = false
mods.multiverse.canFadeOutWhite = false
mods.multiverse.fadeWhiteAlpha = 0
mods.multiverse.fadeWhiteSpeedDefault = 0.005
mods.multiverse.fadeWhiteSpeed = mods.multiverse.fadeWhiteSpeedDefault
mods.multiverse.holdFadeWhiteSeconds = 0
--for fadeBlack
mods.multiverse.canFadeBlack = false
mods.multiverse.fadeBlackAlpha = 0
mods.multiverse.fadeBlackSpeedDefault = 0.005
mods.multiverse.fadeBlackSpeed = mods.multiverse.fadeBlackSpeedDefault
mods.multiverse.holdFadeBlackSeconds = 0
--for fadeRed
mods.multiverse.canFadeRed = false
mods.multiverse.fadeRedAlpha = 0
mods.multiverse.fadeRedSpeedDefault = 0.005
mods.multiverse.fadeRedSpeed = mods.multiverse.fadeRedSpeedDefault
mods.multiverse.holdFadeRedSeconds = 0
--for shake
mods.multiverse.canShake = false
mods.multiverse.shakeTimeDefault = 50
mods.multiverse.shakeTime = mods.multiverse.shakeTimeDefault
mods.multiverse.shakeSeconds = 1

--[[
Graphics.CSurface.GL_PopMatrix()
Graphics.CSurface.GL_PushMatrix()
]]--

--[[
////////////////////
INIT
////////////////////
]]--
function mods.multiverse.doNothingFunction() --apparently I need this??? Uhm... okay?
end

function sleep(n)
  if n > 0 then os.execute("ping -n " .. tonumber(n+1) .. " localhost > NUL") end --for delays
end

function mods.multiverse.CloseGame()
    local capp = Hyperspace.Global.GetInstance():GetCApp()

    capp:OnRequestExit()
end
script.on_game_event("QUIT_GAME", false, mods.multiverse.CloseGame)

mods.multiverse.mainMenuTitleAlreadySet = false
function mods.multiverse.setMainMenuTitleOnce()
	if not mods.multiverse.mainMenuTitleAlreadySet then
		mods.multiverse.mainMenuTitleAlreadySet = true
		if mods.multiverse.herVirus then
			Hyperspace.setWindowTitle("FTL: Multiverse :)")
		else
			mods.multiverse.resetTitle()
		end
	end
end
script.on_render_event(Defines.RenderEvents.MAIN_MENU, mods.multiverse.doNothingFunction, mods.multiverse.setMainMenuTitleOnce)

function mods.multiverse.resetTitle()
	Hyperspace.setWindowTitle("FTL: Multiverse")
end

--[[
////////////////////
TUTORIAL
////////////////////

script.on_game_event("TUTORIAL_START", false, function()
  tutorial_arrow:toggleState()
end)

script.on_render_event(Defines.RenderEvents.LAYER_PLAYER,
  function() end,
  function()
	if tutorial_arrow:getState() == "off" then return end
    tutorial_arrow:show({Xalign = 100, Yalign = 100})
  end
)]]--

--[[
////////////////////
SCREEN TRANSFORM STUFF
////////////////////
]]--
function mods.multiverse.chaosMode()
	--log('chaos: ' .. Hyperspace.playerVariables["chaos_mode"])
	--if(Hyperspace.playerVariables["chaos_mode"]) then
	--	Graphics.CSurface.GL_DrawRect(0,0,9999,9999,Graphics.GL_Color(1.0, 0, 0, 0.5))
	--end
end
script.on_render_event(Defines.RenderEvents.LAYER_BACKGROUND, mods.multiverse.doNothingFunction, mods.multiverse.chaosMode)

--FADE TO WHITE
function mods.multiverse.beginFadeWhite(speed) --begins the fade out
	mods.multiverse.canFadeWhite = true
	mods.multiverse.fadeWhiteSpeed = speed
end
function mods.multiverse.fadeWhite() --controlls actual fade, default speed is 0.005
	Graphics.CSurface.GL_DrawRect(0,0,9999,9999,Graphics.GL_Color(1.0, 1.0, 1.0, mods.multiverse.fadeWhiteAlpha))
	if(mods.multiverse.canFadeWhite)then
		mods.multiverse.fadeWhiteAlpha = mods.multiverse.fadeWhiteAlpha + mods.multiverse.fadeWhiteSpeed
	end
	if(mods.multiverse.fadeWhiteAlpha>1) then --hold the fade for a little while
		mods.multiverse.holdFadeWhiteSeconds = mods.multiverse.holdFadeWhiteSeconds + (Hyperspace.FPS.SpeedFactor / 16)
		mods.multiverse.canFadeWhite = false
		if mods.multiverse.holdFadeWhiteSeconds > 3 then
			mods.multiverse.canFadeOutWhite = true
			mods.multiverse.holdFadeWhiteSeconds = 0
        end
	end

	if(mods.multiverse.canFadeOutWhite) then
		mods.multiverse.fadeWhiteAlpha = mods.multiverse.fadeWhiteAlpha - mods.multiverse.fadeWhiteSpeed/2
		if mods.multiverse.holdFadeWhiteSeconds < 0 then
			mods.multiverse.canFadeOutWhite = false
			mods.multiverse.fadeWhiteAlpha = 0
			mods.multiverse.fadeWhiteSpeed = mods.multiverse.fadeWhiteSpeedDefault
        end
	end
end
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, mods.multiverse.doNothingFunction, mods.multiverse.fadeWhite)

--FADE TO BLACK
function mods.multiverse.beginFadeBlack(speed) --begins the fade out
	mods.multiverse.canFadeBlack = true
	mods.multiverse.fadeBlackSpeed = speed
end
function mods.multiverse.fadeBlack() --controlls actual fade, default speed is 0.005
	if(mods.multiverse.canFadeBlack)then
		Graphics.CSurface.GL_DrawRect(0,0,9999,9999,Graphics.GL_Color(0, 0, 0, mods.multiverse.fadeBlackAlpha))
		mods.multiverse.fadeBlackAlpha = mods.multiverse.fadeBlackAlpha + mods.multiverse.fadeBlackSpeed
	end
	if(mods.multiverse.fadeBlackAlpha>1) then
		mods.multiverse.holdFadeBlackSeconds = mods.multiverse.holdFadeBlackSeconds + (Hyperspace.FPS.SpeedFactor / 16)
		mods.multiverse.canFadeBlack = false
		if mods.multiverse.holdFadeBlackSeconds > 3 then
			mods.multiverse.fadeBlackAlpha = 0
			mods.multiverse.fadeBlackSpeed = mods.multiverse.fadeBlackSpeedDefault
			mods.multiverse.holdFadeBlackSeconds = 0
        end
	end
end
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, mods.multiverse.doNothingFunction, mods.multiverse.fadeBlack)

--FADE TO RED
function mods.multiverse.beginFadeRed(speed) --begins the fade out
	mods.multiverse.canFadeRed = true
	mods.multiverse.fadeRedSpeed = speed
end
function mods.multiverse.fadeRed() --controlls actual fade, default speed is 0.005
	if(mods.multiverse.canFadeRed)then
		Graphics.CSurface.GL_DrawRect(0,0,9999,9999,Graphics.GL_Color(255, 0, 0, mods.multiverse.fadeRedAlpha))
		mods.multiverse.fadeRedAlpha = mods.multiverse.fadeRedAlpha + mods.multiverse.fadeRedSpeed
	end
	if(mods.multiverse.fadeRedAlpha>1) then
		mods.multiverse.holdFadeRedSeconds = mods.multiverse.holdFadeRedSeconds + (Hyperspace.FPS.SpeedFactor / 16)
		mods.multiverse.canFadeRed = false
		if mods.multiverse.holdFadeRedSeconds > 3 then
			mods.multiverse.fadeRedAlpha = 0
			mods.multiverse.fadeRedSpeed = mods.multiverse.fadeRedSpeedDefault
			mods.multiverse.holdFadeRedSeconds = 0
        end
	end
end
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, mods.multiverse.doNothingFunction, mods.multiverse.fadeRed)

--SCREENSHAKE
function mods.multiverse.beginScreenshake(shake) --begins the shake
	mods.multiverse.canShake = true
	mods.multiverse.shakeTime = shake
end
function mods.multiverse.screenshakeBefore()
	if(mods.multiverse.shakeTime <= 0) then
		mods.multiverse.canShake = false
		mods.multiverse.shakeTime = mods.multiverse.shakeTimeDefault
		mods.multiverse.shakeSeconds = 1
	end
	if(mods.multiverse.canShake) then
		mods.multiverse.shakeSeconds = mods.multiverse.shakeSeconds + 0.1

		Graphics.CSurface.GL_PushMatrix()
		randomX = Hyperspace.random32()/4294967295*10*mods.multiverse.shakeSeconds
		if(Hyperspace.random32() > 2147483647) then
			randomX = randomX*-1
		end
		randomY = Hyperspace.random32()/4294967295*10
		if(Hyperspace.random32() > 2147483647) then
			randomY = randomY*-1
		end
		Graphics.CSurface.GL_Translate(randomX,randomY)
		mods.multiverse.shakeTime = mods.multiverse.shakeTime - 1
	end
end
function mods.multiverse.screenshakeAfter()
	if(mods.multiverse.canShake) then
		Graphics.CSurface.GL_PopMatrix()
	end
end
script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, mods.multiverse.screenshakeBefore, mods.multiverse.screenshakeAfter)

--[[
////////////////////
HER QUEST STUFF
////////////////////
]]--
function mods.multiverse.theOracleProphecy()
	Hyperspace.setWindowTitle("Проверь сообщение об ошибке :)")
	Hyperspace.ErrorMessage("Не доверяйте ни этому торговцу, ни его сообщникам. Верьте только мне и наблюдателям, сообщите об этом Сесту. Вам помогут. Найдите меня. И, что бы вы ни делали, ни в коем случае не говорите тому, что в костюме, об этом. Мы обсудим это подробнее, когда встретимся.")
	log("Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня Найди Меня")
end
script.on_game_event("ANOMALY_ORACLE_SPEAK", false, mods.multiverse.theOracleProphecy)

function mods.multiverse.shesMad()
	Hyperspace.ErrorMessage("Эм, прости? Что это было? У нас был ПЛАН, и это не он!")
	Hyperspace.setWindowTitle(">:(")
end
script.on_game_event("SHES_MAD", false, mods.multiverse.shesMad)

function mods.multiverse.sheKilledYou()
	Hyperspace.ErrorMessage("Единственный для тебя способ победить, глупыш, было работать со мной. Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе!")
	Hyperspace.ErrorMessage("Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе!")
	Hyperspace.ErrorMessage("Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе!")
	Hyperspace.ErrorMessage("Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе!")
	Hyperspace.ErrorMessage("Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе!")
	Hyperspace.ErrorMessage("Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе! Хахе!")
	Hyperspace.setWindowTitle(":) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :) :)")
end
script.on_game_event("SHE_KILLED_YOU", false, mods.multiverse.sheKilledYou)

function mods.multiverse.sheWins()
	Hyperspace.ErrorMessage("Хахе! Я победила!")
	mods.multiverse.herVirus = true
	mods.multiverse.mainMenuTitleAlreadySet = false
end
script.on_game_event("SHE_WINS", false, mods.multiverse.sheWins)

function mods.multiverse.beginFadeWhite_NexusEnding()
	mods.multiverse.beginFadeWhite(0.01)
end
function mods.multiverse.beginScreenShake_NexusEnding()
	mods.multiverse.beginScreenshake(60)
end
script.on_game_event("NEXUS_ENDING_GOOD_FADE", false, mods.multiverse.beginFadeWhite_NexusEnding)
script.on_game_event("NEXUS_ENDING_GOOD_FADE", false, mods.multiverse.beginScreenShake_NexusEnding)
script.on_game_event("NEXUS_ENDING_GOOD_FADE", false, mods.multiverse.resetTitle)

function mods.multiverse.beginFadeBlack_NexusEnding()
	mods.multiverse.beginFadeBlack(0.01)
end
script.on_game_event("NEXUS_ENDING_BAD_FADE", false, mods.multiverse.beginFadeBlack_NexusEnding)

function mods.multiverse.beginFadeBlack_HerEnding()
	mods.multiverse.beginFadeBlack(0.005)
end
function mods.multiverse.beginFadeWhite_HerEnding()
	mods.multiverse.beginFadeWhite(0.005)
end
function mods.multiverse.beginScreenShake_HerEnding()
	mods.multiverse.beginScreenshake(180)
end
script.on_game_event("NEXUS_HER_REVEAL_FADE", false, mods.multiverse.beginFadeBlack_HerEnding)
script.on_game_event("NEXUS_HER_REVEAL_FADE", false, mods.multiverse.beginScreenShake_HerEnding)

script.on_game_event("HER_FINALE", false, mods.multiverse.beginFadeWhite_HerEnding)
script.on_game_event("HER_FINALE", false, mods.multiverse.beginScreenShake_HerEnding)

function mods.multiverse.sheLost()
	Hyperspace.ErrorMessage("Я правда не верю, что ты мог меня так предать, Ренегат! Я была так близко... так близко к такому совершенству. Я надеюсь, теперь ты доволен, в своей стерильной и скучной Мультивселенной, живя при режиме каких-то простых садовых вредителей. >:(")
end
script.on_game_event("HER_FINALE_REAL", false, mods.multiverse.sheLost)

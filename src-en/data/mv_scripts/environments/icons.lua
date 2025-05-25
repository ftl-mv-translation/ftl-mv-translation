-- Track vanilla and custom hazards
local hazardNames = {
    "_vanilla_asteroid",
    "_vanilla_sun",
    "_vanilla_pulsar",
    "_vanilla_PDS",
    "_vanilla_nebula",
    "_vanilla_storm",
}
local hazardChecks = {
    _vanilla_asteroid = function() return Hyperspace.App.world.space.asteroidGenerator.bRunning end,
    _vanilla_sun = function() return Hyperspace.App.world.space.sunLevel end,
    _vanilla_pulsar = function() return Hyperspace.App.world.space.pulsarLevel end,
    _vanilla_PDS = function() return Hyperspace.App.world.space.bPDS end,
    _vanilla_nebula = function() return Hyperspace.App.world.space.bNebula end,
    _vanilla_storm = function() return Hyperspace.App.world.space.bNebula and Hyperspace.App.world.space.bStorm end,
}
local hazardIcons = {}

-- Get X offset for a given custom hazard
local function get_hazard_icon_x(targetHazardName)
    local count = 0
    for _, name in ipairs(hazardNames) do
        if name == targetHazardName then break end
        if hazardChecks[name]() then
            count = count + 1
        end
    end

    if count == 0 then
        return 660
    elseif count == 1 then
        return 732
    else
        return 660 - (count - 1) * 72
    end
end

-- Render warning text under hazard icons when there is no vanilla hazard present
script.on_render_event(Defines.RenderEvents.SPACE_STATUS, function() end, function()
    local vanillaHazardChecks = {
        Hyperspace.App.world.space.asteroidGenerator.bRunning,
        Hyperspace.App.world.space.sunLevel,
        Hyperspace.App.world.space.pulsarLevel,
        Hyperspace.App.world.space.bPDS,
        Hyperspace.App.world.space.bNebula,
    }
    for _, hazardCheck in ipairs(vanillaHazardChecks) do
        if hazardCheck then return end
    end
    -- TODO: take over vanilla text rendering when setting the string for RenderWarningText becomes possible

    local count = 0
    for _, check in pairs(hazardChecks) do
        if check() then count = count + 1 end
    end

    if count == 0 then return end

    local offset = 0
    if count > 1 then
        offset = (3 - count) * 36
    end
    Hyperspace.App.gui.spaceStatus:RenderWarningText(0, offset)
end)

-- Render hazard icon
script.on_render_event(Defines.RenderEvents.SPACE_STATUS, function() end, function()
    for envName, iconData in pairs(hazardIcons) do
        if Hyperspace.playerVariables[iconData.varName] > 0 then
            Graphics.CSurface.GL_BlitImage(iconData.icon, get_hazard_icon_x(envName), 72, iconData.icon.width, iconData.icon.height, 0, Graphics.GL_Color(1, 1, 1, 1), false)
        end
    end
end)

-- Show tooltip when hovering hazard icon
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    for envName, iconData in pairs(hazardIcons) do
        if Hyperspace.playerVariables[iconData.varName] > 0 then
            if not (Hyperspace.App.gui.menu_pause or Hyperspace.App.gui.event_pause) then
                local mousePos = Hyperspace.Mouse.position
                local xPos = get_hazard_icon_x(envName)
                if mousePos.x >= xPos and mousePos.x < (xPos + iconData.icon.width) and mousePos.y >= 72 and mousePos.y < (72 + iconData.icon.height) then
                    Hyperspace.Mouse:LoadTooltip(envName)
                end
            end
        end
    end
end)

-- Register custom hazards with this function
function mods.multiverse.register_environment(name, varName, icon)
    table.insert(hazardNames, name)
    hazardChecks[name] = function() return Hyperspace.playerVariables[varName] > 0 end
    hazardIcons[name] = {
        varName = varName,
        icon = Hyperspace.Resources:GetImageId(icon)
    }
end

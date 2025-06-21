local check_paused = mods.multiverse.check_paused

mods.multiverse.icons = mods.multiverse.icons or {}
mods.multiverse.iconsUninstalled = mods.multiverse.iconsUninstalled or {}

local scrollShift = 0 -- tracking the scroll position
local iconPerRow = 5 -- how many icons in one row
local baseOffset = {
    x = 115,
    y = 7
}
local iconSize = {
    x = 24,
    y = 14
}

-- Load the icons from the XML file
do
    local doc = RapidXML.xml_document("data/events_addon_icon.xml")
    local addonNode = (doc:first_node("FTL") or doc):first_node("event")

    while addonNode do
        local iconName = string.sub(addonNode:first_attribute("name"):value(), 7, string.len(addonNode:first_attribute("name"):value()))
        local iconUninstalled = string.find(iconName, "_DISABLED") ~= nil
        local iconHoverText = nil
        if addonNode:first_node("hover-text") then
            if addonNode:first_node("hover-text"):first_attribute("id") then
                iconHoverText = Hyperspace.TextString(addonNode:first_node("hover-text"):first_attribute("id"):value(), false)
            else
                iconHoverText = Hyperspace.TextString(addonNode:first_node("hover-text"):value(), true)
            end
        else
            iconHoverText = Hyperspace.TextString("No hover text found.\nClick to see more info.", true)
        end

        local iconData = {
            name = iconName,
            image = Hyperspace.Resources:CreateImagePrimitiveString("addons/"..string.lower(iconName).."_on.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
            imageHover = Hyperspace.Resources:CreateImagePrimitiveString("addons/"..string.lower(iconName).."_select2.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
            event = "ADDON_"..iconName,
            hover = false,
            hoverText = iconHoverText
        }

        if iconUninstalled then
            table.insert(mods.multiverse.iconsUninstalled, iconData)
        else
            table.insert(mods.multiverse.icons, iconData)
        end
        addonNode = addonNode:next_sibling("event")
    end

    doc:clear()
end

-- Render individual icons
local function render_icon(iconData, iconCounter)

    -- return if not the correct Shift
    if iconCounter < scrollShift*iconPerRow or iconCounter >= ((scrollShift + 1)*iconPerRow) then return end

    local xOffset = (baseOffset.x + ((iconCounter - scrollShift*iconPerRow)*iconSize.x))
    local yOffset = baseOffset.y
    local mousePos = Hyperspace.Mouse.position

    if math.abs(mousePos.x - xOffset - 12) < 12 and math.abs(mousePos.y - yOffset - 7) < 7 then
        iconData.hover = true
        Hyperspace.Mouse.tooltip = iconData.hoverText:GetText()
    else
        iconData.hover = false
    end

    Graphics.CSurface.GL_PushMatrix()
    Graphics.CSurface.GL_Translate(xOffset,yOffset,0)

    if iconData.hover then
        Graphics.CSurface.GL_RenderPrimitive(iconData.imageHover)
    else
        Graphics.CSurface.GL_RenderPrimitive(iconData.image)
    end

    Graphics.CSurface.GL_PopMatrix()
end

-- Render all icons
script.on_render_event(Defines.RenderEvents.SHIP_STATUS, function()
    if Hyperspace.App.world.bStartedGame then
        local renderedAddons = {}
        local iconCounter = 0

        for _, iconData in ipairs(mods.multiverse.icons) do
            renderedAddons[iconData.name.."_DISABLED"] = true
            render_icon(iconData, iconCounter)
            iconCounter = iconCounter + 1
        end

        for _, iconData in ipairs(mods.multiverse.iconsUninstalled) do
            if not renderedAddons[iconData.name] then
                render_icon(iconData, iconCounter)
                iconCounter = iconCounter + 1
            end
        end
    end
end, function() end)

-- Show info for an addon on click
script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x, y)
    local cmdGui = Hyperspace.App.gui
    if Hyperspace.App.world.bStartedGame and not check_paused() then
        for _, iconData in ipairs(mods.multiverse.icons) do
            if iconData.hover then
                local worldManager = Hyperspace.App.world
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager, iconData.event, false, -1)
            end
        end
        for _, iconData in ipairs(mods.multiverse.iconsUninstalled) do
            if iconData.hover then
                local worldManager = Hyperspace.App.world
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager, iconData.event, false, -1)
            end
        end
    end
end)

-- Scroll through addons if so many are installed that they don't all fit
script.on_internal_event(Defines.InternalEvents.ON_MOUSE_SCROLL, function(direction)
    if Hyperspace.App.world.bStartedGame then
        local mousePos = Hyperspace.Mouse.position
        if mousePos.x > baseOffset.x and mousePos.x < baseOffset.x + iconPerRow*iconSize.x and mousePos.y > baseOffset.y and mousePos.y < baseOffset.y + iconSize.y then
            if direction == -1 then
                scrollShift = scrollShift - 1
            elseif direction == 1 then
                scrollShift = scrollShift + 1
            end

            if scrollShift < 0 then
                scrollShift = 0
            end

            if scrollShift*iconPerRow >= #mods.multiverse.icons + #mods.multiverse.iconsUninstalled then
                scrollShift = math.floor((#mods.multiverse.icons + #mods.multiverse.iconsUninstalled)/iconPerRow)
            end
        end
    end
end)
